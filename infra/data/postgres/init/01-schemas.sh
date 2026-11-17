#!/bin/bash
# Runs once, as superuser, when the Postgres volume is empty.
# One role + one schema per service. Passwords come from infra/.env.
set -e
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
  -- ./scripts/new-service.sh appends one role + schema per service below.
  CREATE ROLE catalog_svc LOGIN PASSWORD '${CATALOG_DB_PASSWORD}';
  CREATE SCHEMA catalog_svc AUTHORIZATION catalog_svc;
EOSQL