#!/usr/bin/env bash
# Shared helpers for new-service.sh and sync-service.sh. Source it, do not run it.

BASE_PKG_DIR="com/ppossatto"
BASE_PKG="com.ppossatto"
TEMPLATE_PATH="services/_template"
TEMPLATE_REF_FILE=".template-ref"

# Files that belong to the Item/Catalog example. They are replaced by each service's
# real domain, so template changes to them are never synced.
EXAMPLE_FILES_REGEX='/(Item[A-Za-z]*|Catalog[A-Za-z]*)\.java$|/V1__create_item_table\.sql$|/catalog-sku-exists\.json$'

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