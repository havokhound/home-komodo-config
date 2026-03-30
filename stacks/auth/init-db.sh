#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    CREATE USER lldap WITH PASSWORD '${LLDAP_DB_PASSWORD}';
    CREATE DATABASE lldap OWNER lldap;

    CREATE USER authelia WITH PASSWORD '${AUTHELIA_DB_PASSWORD}';
    CREATE DATABASE authelia OWNER authelia;
EOSQL
