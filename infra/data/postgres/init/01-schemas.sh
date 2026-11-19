#!/bin/bash
# Runs once, as superuser, when the Postgres volume is empty.
# One role + one schema per service. Passwords come from infra/.env.
set -e
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
  -- ./scripts/new-service.sh appends one role + schema per service below.
  CREATE ROLE catalog_svc LOGIN PASSWORD '${CATALOG_DB_PASSWORD}';
  CREATE SCHEMA catalog_svc AUTHORIZATION catalog_svc;
  CREATE ROLE order_svc LOGIN PASSWORD '${ORDER_DB_PASSWORD}';
  CREATE SCHEMA order_svc AUTHORIZATION order_svc;
  CREATE ROLE payment_svc LOGIN PASSWORD '${PAYMENT_DB_PASSWORD}';
  CREATE SCHEMA payment_svc AUTHORIZATION payment_svc;
  CREATE ROLE notifications_svc LOGIN PASSWORD '${NOTIFICATIONS_DB_PASSWORD}';
  CREATE SCHEMA notifications_svc AUTHORIZATION notifications_svc;
EOSQL