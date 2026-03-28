# Komodo Setup Guide — Verdaccio Stack

## Prerequisites

- Komodo 2.0 running and connected to your server
- GitHub PAT configured in Komodo (Contents: Read on havokhound/home-komodo-config)
- NFS share ownership fixed (see Task 3 in implementation plan)

## Step 1: Configure Git Provider

1. Go to **Settings → Git Providers**
2. Click **Add Provider**
3. Set:
   - **Domain:** `github.com`
   - **Username:** your GitHub username
   - **Token:** your PAT (Contents: Read)
4. Save

## Step 2: Create the Stack via Git Sync

1. Go to **Stacks → New Stack**
2. Set:
   - **Name:** `verdaccio`
   - **Source:** Git
   - **Repo:** `havokhound/home-komodo-config`
   - **Branch:** `main`
   - **Compose file path:** `stacks/verdaccio/compose.yaml`
3. Select your server
4. Save and deploy

## Step 3: Add the First User

Verdaccio does not allow self-registration (`max_users: -1`). Add users manually using `htpasswd` via the container:

```bash
docker exec verdaccio htpasswd -B /verdaccio/storage/.htpasswd <username>
```

Enter a password when prompted. The user can now publish packages.

## Step 4: Configure npm clients

On any machine that needs to install or publish:

```bash
# Set registry for all packages
npm config set registry https://npm.havokhound.co.uk

# Or scope it (recommended for private packages)
npm config set @havokhound:registry https://npm.havokhound.co.uk

# Login (required to publish)
npm login --registry https://npm.havokhound.co.uk
```

## Step 5: Configure reverse proxy

Verdaccio listens on port `4873`. Point `npm.havokhound.co.uk` to this port via your reverse proxy. Traefik labels will be added to `compose.yaml` once the Traefik network is set up on this Docker host.

## Syncing config changes

Any change to `stacks/verdaccio/config.yaml` pushed to `main` will be picked up by Komodo on the next sync. Trigger a manual sync or wait for the configured interval. Komodo will restart the stack automatically if the compose file changes.
