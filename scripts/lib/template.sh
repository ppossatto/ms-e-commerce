#!/usr/bin/env bash
# Shared helpers for new-service.sh and sync-service.sh. Source it, do not run it.

BASE_PKG_DIR="com/ppossatto"
BASE_PKG="com.ppossatto"
TEMPLATE_PATH="services/_template"
TEMPLATE_REF_FILE=".template-ref"

# Files that belong to the Item/Catalog example. They are replaced by each service's
# real domain, so template changes to them are never synced.
# Exact file names (not prefixes), so a real service such as catalog-service keeps
# syncing its own Catalog*.java files (e.g. CatalogApplication.java).
EXAMPLE_FILES_REGEX='/(Item|ItemNotInCatalogException|CreateItemUseCase|FindItemUseCase|ItemRepository|CatalogPort|ItemService|ItemServiceTest|ItemJpaEntity|ItemJpaRepository|ItemPersistenceAdapter|CatalogHttpAdapter|ItemController|ItemFlowIT)\.java$|/V1__create_item_table\.sql$|/catalog-sku-exists\.json$'

# Sets NAME-derived variables: PKG, PASCAL, UPPER, ROLE.
derive_names() {
  local name="$1"
  PKG="$(echo "${name%-service}" | tr -cd 'a-z0-9')"
  PASCAL="$(echo "${name%-service}" | sed -E 's/(^|-)([a-z])/\U\2/g')"
  UPPER="$(echo "$PKG" | tr 'a-z' 'A-Z')"
  ROLE="${PKG}_svc"
}

# render_template <template-dir> <dest-dir> <service-name>
# Copies the template and applies every rename (package, main class, artifactId, role/schema).
render_template() {
  local src="$1" dest="$2" name="$3"
  derive_names "$name"

  mkdir -p "$dest"
  cp -r "$src/." "$dest/"
  rm -rf "$dest/target"

  local base
  for base in src/main/java src/test/java; do
    if [ -d "$dest/$base/$BASE_PKG_DIR/template" ]; then
      mv "$dest/$base/$BASE_PKG_DIR/template" "$dest/$base/$BASE_PKG_DIR/$PKG"
    fi
  done
  local main_dir="$dest/src/main/java/$BASE_PKG_DIR/$PKG"
  [ -f "$main_dir/TemplateApplication.java" ] && mv "$main_dir/TemplateApplication.java" "$main_dir/${PASCAL}Application.java"

  # Replacements: most specific first, most generic last
  find "$dest" -type f \( -name '*.java' -o -name '*.xml' -o -name '*.yaml' -o -name '*.sql' \) -print0 |
    xargs -0 -r sed -i -E \
      -e "s/template-service/${name}/g" \
      -e "s/template_svc/${ROLE}/g" \
      -e "s/TemplateApplication/${PASCAL}Application/g" \
      -e "s/${BASE_PKG//./\\.}\.template/${BASE_PKG}.${PKG}/g" \
      -e "s/\btemplate\b/${PKG}/g"
}

# Last commit that changed the template (empty if not a git repository).
template_head() {
  git -C "$1" log -1 --format=%H -- "$TEMPLATE_PATH" 2>/dev/null || true
}

# write_workflow <repo-root> <service-name>
# (Re)writes .github/workflows/<name>.yml. Overwrites the file if it exists.
#   pull request / push to main : build + tests + SonarQube Cloud analysis
#   tag <name>/v<semver>        : the same + image ghcr.io/<owner>/<name>:<semver> and :latest
#   manual run                  : the same + image ghcr.io/<owner>/<name>:sha-<short-sha>
write_workflow() {
  local root="$1" name="$2"
  local wf="$root/.github/workflows/$name.yml"
  mkdir -p "$(dirname "$wf")"
  # Quoted heredoc: GitHub expressions (${{ ... }}) stay literal; __NAME__ is replaced afterwards.
  cat > "$wf" <<'EOF'
name: __NAME__

on:
  pull_request:
    paths: ["services/__NAME__/**", "build-parent/**", "contracts/**"]
  push:
    branches: [main]
    # Path filters are not evaluated for tag pushes, so a release tag always runs.
    tags: ["__NAME__/v*"]
    paths: ["services/__NAME__/**", "build-parent/**", "contracts/**"]
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  build:
    runs-on: ubuntu-latest
    env:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0 # full history for SonarQube Cloud (blame, new code detection)

      - uses: actions/setup-java@v6
        with:
          distribution: temurin
          java-version: "25"
          cache: maven

      - name: Cache SonarQube Cloud packages
        if: env.SONAR_TOKEN != ''
        uses: actions/cache@v6
        with:
          path: ~/.sonar/cache
          key: ${{ runner.os }}-sonar
          restore-keys: ${{ runner.os }}-sonar

      # Sonar runs in the same Maven call, reusing the build and the JaCoCo reports.
      # Skipped when SONAR_TOKEN is not available (e.g. pull requests from forks).
      - name: Build, test and analyze
        working-directory: services/__NAME__
        run: |
          if [ -n "$SONAR_TOKEN" ]; then
            mvn -B verify org.sonarsource.scanner.maven:sonar-maven-plugin:sonar -Dsonar.qualitygate.wait=true
          else
            echo "SONAR_TOKEN not set: skipping SonarQube Cloud analysis."
            mvn -B verify
          fi

      # ---- Image: only for release tags and manual runs ----
      - name: Image tags
        id: image
        if: startsWith(github.ref, 'refs/tags/__NAME__/v') || github.event_name == 'workflow_dispatch'
        run: |
          image="ghcr.io/${GITHUB_REPOSITORY_OWNER,,}/__NAME__"
          if [[ "$GITHUB_REF" == refs/tags/__NAME__/v* ]]; then
            version="${GITHUB_REF_NAME#__NAME__/v}"
            echo "tags=${image}:${version},${image}:latest" >> "$GITHUB_OUTPUT"
          else
            echo "tags=${image}:sha-${GITHUB_SHA::7}" >> "$GITHUB_OUTPUT"
          fi

      - name: Log in to GitHub Container Registry
        if: steps.image.outputs.tags != ''
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up Docker Buildx
        if: steps.image.outputs.tags != ''
        uses: docker/setup-buildx-action@v4

      - name: Build and push image
        if: steps.image.outputs.tags != ''
        uses: docker/build-push-action@v7
        with:
          context: services/__NAME__
          push: true
          tags: ${{ steps.image.outputs.tags }}
          labels: |
            org.opencontainers.image.source=${{ github.server_url }}/${{ github.repository }}
            org.opencontainers.image.revision=${{ github.sha }}
EOF
  sed -i "s/__NAME__/${name}/g" "$wf"
}