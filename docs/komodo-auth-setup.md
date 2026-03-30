# Komodo Setup Guide — Auth Stack (LLDAP + Authelia + PostgreSQL)

## Prerequisites

- Komodo 2.0 running and connected to `fedora-server`
- GitHub PAT configured in Komodo
- NFS directories created on NAS (192.168.50.64):
  - `/volume1/auth/postgres`
  - `/volume1/auth/lldap`
- NFS exports configured with same permissions as `/volume1/registry/npm`

## Step 1: Create the Docker Network

On `fedora-server`, create the shared external network:

```bash
docker network create auth-net
```

This network is shared between the `auth` and `verdaccio` stacks.

## Step 2: Configure Secrets

The auth stack requires the following secrets. Generate strong random values and configure them in Komodo as environment variables for the `auth` stack, or place them in a `.env` file on the server in the stack's run directory.

| Variable | Description | Notes |
|----------|-------------|-------|
| `POSTGRES_PASSWORD` | PostgreSQL superuser password | Used only by the postgres container |
| `LLDAP_JWT_SECRET` | LLDAP JWT signing key | Random string, min 20 chars |
| `LLDAP_LDAP_USER_PASS` | LLDAP admin password | Used to log into LLDAP web UI and as bind password |
| `LLDAP_DB_PASSWORD` | LLDAP PostgreSQL user password | Must match what init-db.sh creates |
| `AUTHELIA_JWT_SECRET` | Authelia identity validation JWT | Random string, min 20 chars |
| `AUTHELIA_SESSION_SECRET` | Authelia session encryption | Random string, min 20 chars |
| `AUTHELIA_STORAGE_ENCRYPTION_KEY` | Authelia storage encryption key | Random string, min 20 chars |
| `AUTHELIA_DB_PASSWORD` | Authelia PostgreSQL user password | Must match what init-db.sh creates |

Generate secrets with:
```bash
openssl rand -hex 32
```

## Step 3: Deploy the Auth Stack

1. Go to **Stacks → New Stack**
2. Set:
   - **Name:** `auth`
   - **Source:** Git
   - **Repo:** `havokhound/home-komodo-config`
   - **Branch:** `main`
   - **Compose file path:** `stacks/auth/compose.yaml`
3. Select `fedora-server`
4. Add the environment variables from Step 2
5. Save and deploy

## Step 4: Verify Services

1. **PostgreSQL**: Check databases exist:
   ```bash
   docker exec auth-postgres psql -U postgres -c '\l'
   ```
   You should see both `lldap` and `authelia` databases.

2. **LLDAP**: Browse to `https://ldap.havokhound.co.uk`
   - Log in with username `admin` and `LLDAP_LDAP_USER_PASS`
   - The admin panel should load

3. **Authelia**: Browse to `https://auth.havokhound.co.uk`
   - The login portal should appear

## Step 5: Create Initial Users and Groups

1. In LLDAP admin (`https://ldap.havokhound.co.uk`):
   - **Create a group** (e.g., `admins`, `users`)
   - **Create a user** with username, email, display name
   - **Assign the user to a group**

2. Test authentication at `https://auth.havokhound.co.uk` with the new user credentials

## Step 6: Configure Traefik Forward Auth (Optional)

To protect other services with Authelia, add these Traefik labels to any service:

```yaml
labels:
  - traefik.http.routers.myservice.middlewares=authelia@docker
```

And add the Authelia forwardAuth middleware to your Traefik configuration:

```yaml
http:
  middlewares:
    authelia:
      forwardAuth:
        address: http://auth-authelia:9091/api/authz/forward-auth
        trustForwardHeader: true
        authResponseHeaders:
          - Remote-User
          - Remote-Groups
          - Remote-Email
          - Remote-Name
```

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  stacks/auth/ (combined stack on fedora-server)          │
│                                                          │
│  ┌──────────┐   ┌──────────┐   ┌───────────────────┐    │
│  │  LLDAP   │──▶│PostgreSQL│◀──│    Authelia        │    │
│  │ :3890    │   │  :5432   │   │    :9091           │    │
│  │ :17170   │   │          │   │                    │    │
│  └──────────┘   └──────────┘   └───────────────────┘    │
│       ▲                              ▲                   │
└───────┼──────────────────────────────┼───────────────────┘
   Traefik                        Traefik
   ldap.havokhound.co.uk          auth.havokhound.co.uk
```

## Syncing Config Changes

Changes to `stacks/auth/authelia-configuration.yml` pushed to `main` will be picked up by Komodo. Authelia will be redeployed automatically. Changes to `init-db.sh` only take effect if the PostgreSQL data volume is recreated (the init script runs only on first database initialization).
