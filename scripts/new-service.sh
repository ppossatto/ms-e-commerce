#!/usr/bin/env bash
# Creates a new service from services/_template.
# Usage (from the repository root): ./scripts/new-service.sh order-service
#
# For "order-service" it generates:
#   directory/artifactId : services/order-service
#   package              : com.ppossatto.order
#   role and schema      : order_svc
#   main class           : OrderApplication
set -euo pipefail

NAME="${1:?Usage: $0 <service-name>  (e.g. order-service)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/services/_template"
DEST="$ROOT/services/$NAME"
BASE_PKG_DIR="com/ppossatto"
BASE_PKG="com.ppossatto"

[[ "$NAME" =~ ^[a-z][a-z0-9-]*$ ]] || { echo "Invalid name: use lowercase letters, digits and hyphens." >&2; exit 1; }
[ -e "$DEST" ] && { echo "Already exists: $DEST" >&2; exit 1; }

PKG="$(echo "${NAME%-service}" | tr -cd 'a-z0-9')"
PASCAL="$(echo "${NAME%-service}" | sed -E 's/(^|-)([a-z])/\U\2/g')"

cp -r "$SRC" "$DEST"
rm -rf "$DEST/target"

# Move package <base>/template -> <base>/<pkg>
for base in src/main/java src/test/java; do
  mv "$DEST/$base/$BASE_PKG_DIR/template" "$DEST/$base/$BASE_PKG_DIR/$PKG"
done
mv "$DEST/src/main/java/$BASE_PKG_DIR/$PKG/TemplateApplication.java" \
   "$DEST/src/main/java/$BASE_PKG_DIR/$PKG/${PASCAL}Application.java"

# Replacements: most specific first, most generic last
find "$DEST" -type f \( -name '*.java' -o -name '*.xml' -o -name '*.yaml' -o -name '*.sql' \) -print0 |
  xargs -0 sed -i -E \
    -e "s/template-service/${NAME}/g" \
    -e "s/template_svc/${PKG}_svc/g" \
    -e "s/TemplateApplication/${PASCAL}Application/g" \
    -e "s/${BASE_PKG//./\\.}\.template/${BASE_PKG}.${PKG}/g" \
    -e "s/\btemplate\b/${PKG}/g"

# Service CI workflow (runs only when the service, the parent or the contracts change)
WF="$ROOT/.github/workflows/$NAME.yml"
if [ ! -e "$WF" ]; then
  mkdir -p "$(dirname "$WF")"
  cat > "$WF" <<EOF
name: $NAME

on:
  push:
    paths: ["services/$NAME/**", "build-parent/**", "contracts/**"]
  pull_request:
    paths: ["services/$NAME/**", "build-parent/**", "contracts/**"]

jobs:
  build:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: services/$NAME
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: "25"
          cache: maven
      - run: mvn -B verify
EOF
fi

UPPER="$(echo "$PKG" | tr 'a-z' 'A-Z')"
cat <<EOF
Created: services/$NAME (package ${BASE_PKG}.$PKG, role/schema ${PKG}_svc)

Next steps:
  1. Add to infra/data/postgres/init/01-schemas.sh:
       CREATE ROLE ${PKG}_svc LOGIN PASSWORD '\${${UPPER}_DB_PASSWORD}';
       CREATE SCHEMA ${PKG}_svc AUTHORIZATION ${PKG}_svc;
  2. Add ${UPPER}_DB_PASSWORD to infra/.env.example
  3. Replace the Item/Catalog example with the service's real domain.
EOF
