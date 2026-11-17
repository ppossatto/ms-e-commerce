#!/usr/bin/env bash
# Creates a new service from services/_template.
# Usage (from the repository root): ./scripts/new-service.sh order-service
#
# For "order-service" it generates:
#   directory/artifactId : services/order-service
#   package              : com.ppossatto.order
#   role and schema      : order_svc
#   main class           : OrderApplication
#   CI workflow          : .github/workflows/order-service.yml (build, test, push image to GHCR)
# and registers the role/schema in Postgres init and the password in .env.example.
set -euo pipefail

NAME="${1:?Usage: $0 <service-name>  (e.g. order-service)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/services/_template"
DEST="$ROOT/services/$NAME"
BASE_PKG_DIR="com/ppossatto"
BASE_PKG="com.ppossatto"
SCHEMAS_FILE="$ROOT/infra/data/postgres/init/01-schemas.sh"
ENV_FILE="$ROOT/infra/.env.example"

[[ "$NAME" =~ ^[a-z][a-z0-9-]*$ ]] || { echo "Invalid name: use lowercase letters, digits and hyphens." >&2; exit 1; }
[ -e "$DEST" ] && { echo "Already exists: $DEST" >&2; exit 1; }

PKG="$(echo "${NAME%-service}" | tr -cd 'a-z0-9')"
PASCAL="$(echo "${NAME%-service}" | sed -E 's/(^|-)([a-z])/\U\2/g')"
UPPER="$(echo "$PKG" | tr 'a-z' 'A-Z')"
ROLE="${PKG}_svc"
PKG_DIR="src/main/java/$BASE_PKG_DIR/$PKG"
TEST_DIR="src/test/java/$BASE_PKG_DIR/$PKG"

# ---------------------------------------------------------------- 1. Copy template
cp -r "$SRC" "$DEST"
rm -rf "$DEST/target"

for base in src/main/java src/test/java; do
  mv "$DEST/$base/$BASE_PKG_DIR/template" "$DEST/$base/$BASE_PKG_DIR/$PKG"
done
mv "$DEST/$PKG_DIR/TemplateApplication.java" "$DEST/$PKG_DIR/${PASCAL}Application.java"

# Replacements: most specific first, most generic last
find "$DEST" -type f \( -name '*.java' -o -name '*.xml' -o -name '*.yaml' -o -name '*.sql' \) -print0 |
  xargs -0 sed -i -E \
    -e "s/template-service/${NAME}/g" \
    -e "s/template_svc/${ROLE}/g" \
    -e "s/TemplateApplication/${PASCAL}Application/g" \
    -e "s/${BASE_PKG//./\\.}\.template/${BASE_PKG}.${PKG}/g" \
    -e "s/\btemplate\b/${PKG}/g"

# ---------------------------------------------------------------- 2. Postgres role/schema + .env.example
if ! grep -q "CREATE ROLE ${ROLE} " "$SCHEMAS_FILE"; then
  sed -i "/^EOSQL$/i\\
  CREATE ROLE ${ROLE} LOGIN PASSWORD '\${${UPPER}_DB_PASSWORD}';\\
  CREATE SCHEMA ${ROLE} AUTHORIZATION ${ROLE};" "$SCHEMAS_FILE"
fi
grep -q "^${UPPER}_DB_PASSWORD=" "$ENV_FILE" || printf '%s_DB_PASSWORD=\n' "$UPPER" >> "$ENV_FILE"

# ---------------------------------------------------------------- 3. CI workflow
# Quoted heredoc: GitHub expressions (${{ ... }}) are kept literally; __NAME__ is replaced afterwards.
WF="$ROOT/.github/workflows/$NAME.yml"
if [ ! -e "$WF" ]; then
  mkdir -p "$(dirname "$WF")"
  cat > "$WF" <<'EOF'
name: __NAME__

on:
  push:
    branches: [main]
    paths: ["services/__NAME__/**", "build-parent/**", "contracts/**"]
  pull_request:
    paths: ["services/__NAME__/**", "build-parent/**", "contracts/**"]

permissions:
  contents: read
  packages: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - uses: actions/setup-java@v6
        with:
          distribution: temurin
          java-version: "25"
          cache: maven

      - name: Build and test
        working-directory: services/__NAME__
        run: mvn -B verify

      # The image is published only on push to main, never on pull requests.
      - name: Log in to GitHub Container Registry
        if: github.event_name == 'push'
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Image metadata
        if: github.event_name == 'push'
        id: meta
        uses: docker/metadata-action@v6
        with:
          images: ghcr.io/${{ github.repository_owner }}/__NAME__
          tags: |
            type=sha
            type=raw,value=latest

      - name: Set up Docker Buildx
        if: github.event_name == 'push'
        uses: docker/setup-buildx-action@v4

      - name: Build and push image
        if: github.event_name == 'push'
        uses: docker/build-push-action@v7
        with:
          context: services/__NAME__
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
EOF
  sed -i "s/__NAME__/${NAME}/g" "$WF"
fi

# ---------------------------------------------------------------- Summary
cat <<EOF
Created services/$NAME
  package     : ${BASE_PKG}.$PKG
  main class  : ${PASCAL}Application
  role/schema : ${ROLE}
  CI workflow : .github/workflows/$NAME.yml (image: ghcr.io/<owner>/$NAME)

Done automatically:
  - infra/data/postgres/init/01-schemas.sh : CREATE ROLE/SCHEMA ${ROLE}
  - infra/.env.example                     : ${UPPER}_DB_PASSWORD=

Next: replace the Item/Catalog example with the real domain (paths under services/$NAME/):
  1. Domain model
     $PKG_DIR/domain/model/Item.java
       -> rename to your aggregate (e.g. Order.java), keep it plain Java (no Spring/JPA).
     $PKG_DIR/domain/model/ItemNotInCatalogException.java
       -> replace with your domain exceptions, or delete it.
  2. Ports
     $PKG_DIR/domain/port/in/*UseCase.java
       -> one interface per use case the service exposes (e.g. PlaceOrderUseCase).
     $PKG_DIR/domain/port/out/ItemRepository.java, CatalogPort.java
       -> what the use cases need from the outside (persistence, other services, Kafka).
  3. Application
     $PKG_DIR/application/ItemService.java
       -> implement the new use cases using only the ports.
     $PKG_DIR/config/UseCaseConfig.java
       -> update the @Bean that wires the service with its ports.
  4. Adapters
     $PKG_DIR/adapter/in/web/ItemController.java       -> REST endpoints (or implement the OpenAPI-generated interface).
     $PKG_DIR/adapter/out/persistence/*                -> JPA entity, Spring Data repository, port implementation.
     $PKG_DIR/adapter/out/http/CatalogHttpAdapter.java -> delete or replace with your outbound clients.
  5. Database
     src/main/resources/db/migration/V1__create_item_table.sql
       -> rename to V1__<your_table>.sql with your tables (schema ${ROLE} is set automatically).
  6. Configuration
     src/main/resources/application.yaml
       -> remove "clients.catalog" if unused; add your own client URLs.
     src/test/resources/application-local.yaml
       -> point each client base-url to WireMock (http://localhost:\${wiremock.port}).
     src/test/resources/wiremock/mappings/catalog-sku-exists.json
       -> replace with stubs for your external endpoints (bodies go in wiremock/__files/).
     Run locally: mvn spring-boot:test-run -Dspring-boot.run.profiles=local
  7. Tests
     $TEST_DIR/application/ItemServiceTest.java -> unit tests for the new use cases (Mockito).
     $TEST_DIR/ItemFlowIT.java                  -> integration tests (Testcontainers + WireMock).
     $TEST_DIR/ArchitectureTest.java            -> keep as is: it enforces the hexagonal rules.

Then run: (cd services/$NAME && mvn spotless:apply verify)
EOF