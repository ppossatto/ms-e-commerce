#!/usr/bin/env bash
# Brings template changes into services that were already generated.
#
# Usage (from the repository root):
#   ./scripts/sync-service.sh order-service             # one service
#   ./scripts/sync-service.sh --all                     # every service with a .template-ref
#   ./scripts/sync-service.sh order-service --dry-run   # only show what would change
#   ./scripts/sync-service.sh order-service --workflow  # also regenerate .github/workflows/<name>.yml
#   ./scripts/sync-service.sh order-service --from <commit>
#        # for services created before .template-ref existed: the commit of services/_template
#        # the service was generated from
#
# How it works (3-way merge, the same idea as a git merge):
#   base   = template at the commit recorded in services/<name>/.template-ref, renamed for the service
#   theirs = template now (last commit), renamed for the service
#   ours   = the service as it is
# Only what changed in the template between base and theirs is applied, so the service's own
# code is kept. If both sides changed the same lines, the file gets conflict markers
# (<<<<<<< / >>>>>>>) to resolve by hand, as in a git merge.
#
# The CI workflow lives outside services/, so it is not merged. --workflow rewrites it from the
# current generator (scripts/lib/template.sh); review the result with "git diff".
#
# Never touched: the Item/Catalog example files (see EXAMPLE_FILES_REGEX in lib/template.sh)
# and files deleted from the service on purpose. Files removed from the template are reported,
# not deleted.
#
# Exit codes: 0 ok, 1 error, 2 conflicts to resolve.
#
# Requirements: a git repository, template changes committed, and a clean working tree
# for the service, so the result can be reviewed with "git diff" and undone with "git restore".
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/template.sh
source "$ROOT/scripts/lib/template.sh"

usage() { sed -n '3,11p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }

DRY_RUN=false
WORKFLOW=false
ALL=false
FROM=""
NAMES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --all) ALL=true ;;
    --workflow) WORKFLOW=true ;;
    --from) FROM="${2:?--from needs a commit}"; shift ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *) NAMES+=("$1") ;;
  esac
  shift
done

git -C "$ROOT" rev-parse --is-inside-work-tree > /dev/null 2>&1 || { echo "Not a git repository." >&2; exit 1; }
if [ -n "$(git -C "$ROOT" status --porcelain -- "$TEMPLATE_PATH")" ]; then
  echo "services/_template has uncommitted changes. Commit them first." >&2
  exit 1
fi

TARGET_REF="$(template_head "$ROOT")"
[ -n "$TARGET_REF" ] && [ -d "$ROOT/$TEMPLATE_PATH" ] || { echo "services/_template is not committed yet." >&2; exit 1; }

if $ALL; then
  [ -n "$FROM" ] && { echo "--from cannot be combined with --all." >&2; exit 1; }
  for ref_file in "$ROOT"/services/*/"$TEMPLATE_REF_FILE"; do
    [ -e "$ref_file" ] || continue
    dir="$(dirname "$ref_file")"
    [ "$(basename "$dir")" = "_template" ] || NAMES+=("$(basename "$dir")")
  done
fi
[ ${#NAMES[@]} -gt 0 ] || usage

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Extracts services/_template at <commit> into <dir>.
extract_template() {
  local commit="$1" dir="$2"
  mkdir -p "$dir"
  git -C "$ROOT" archive "$commit" "$TEMPLATE_PATH" | tar -x -C "$dir"
}

sync_one() {
  local name="$1" svc="$ROOT/services/$1"
  [ -d "$svc" ] || { echo "[$name] not found: services/$name" >&2; return 1; }

  local base_ref="$FROM"
  if [ -z "$base_ref" ]; then
    [ -f "$svc/$TEMPLATE_REF_FILE" ] || {
      echo "[$name] no $TEMPLATE_REF_FILE. Run again with --from <commit>." >&2
      echo "        Hint: git log --oneline -- $TEMPLATE_PATH" >&2
      return 1
    }
    base_ref="$(cat "$svc/$TEMPLATE_REF_FILE")"
  fi
  git -C "$ROOT" cat-file -e "${base_ref}^{commit}" 2>/dev/null || { echo "[$name] unknown commit: $base_ref" >&2; return 1; }

  if $WORKFLOW; then
    if $DRY_RUN; then
      echo "[$name] would rewrite .github/workflows/$name.yml"
    else
      write_workflow "$ROOT" "$name"
      echo "[$name] rewrote .github/workflows/$name.yml"
    fi
  fi

  if [ "$(git -C "$ROOT" rev-parse "$base_ref")" = "$TARGET_REF" ]; then
    echo "[$name] already up to date (${TARGET_REF:0:8})."
    return 0
  fi
  if ! $DRY_RUN && [ -n "$(git -C "$ROOT" status --porcelain -- "services/$name")" ]; then
    echo "[$name] has uncommitted changes. Commit or stash them first." >&2
    return 1
  fi

  local work="$TMP/$name"
  extract_template "$base_ref" "$work/raw-base"
  extract_template "$TARGET_REF" "$work/raw-theirs"
  render_template "$work/raw-base/$TEMPLATE_PATH" "$work/base" "$name"
  render_template "$work/raw-theirs/$TEMPLATE_PATH" "$work/theirs" "$name"

  local added=() updated=() conflicts=() skipped=() removed=()
  local rel ours base theirs
  while IFS= read -r rel; do
    [[ "/$rel" =~ $EXAMPLE_FILES_REGEX ]] && continue
    ours="$svc/$rel"; base="$work/base/$rel"; theirs="$work/theirs/$rel"

    if [ ! -e "$theirs" ]; then                     # removed from the template
      [ -e "$ours" ] && removed+=("$rel")
      continue
    fi
    if [ -e "$base" ] && cmp -s "$base" "$theirs"; then
      continue                                      # template did not change this file
    fi
    if [ ! -e "$base" ]; then                       # new in the template
      if [ ! -e "$ours" ]; then
        added+=("$rel")
        $DRY_RUN || { mkdir -p "$(dirname "$ours")"; cp "$theirs" "$ours"; }
      elif ! cmp -s "$ours" "$theirs"; then
        conflicts+=("$rel (exists in the service with different content)")
        $DRY_RUN || git merge-file -q -L "services/$name" -L "template (empty)" -L "template (new)" \
          "$ours" /dev/null "$theirs" || true
      fi
      continue
    fi
    if [ ! -e "$ours" ]; then                       # deleted from the service on purpose
      skipped+=("$rel")
      continue
    fi
    if $DRY_RUN; then
      cp "$ours" "$work/probe"
      if git merge-file -q "$work/probe" "$base" "$theirs"; then updated+=("$rel"); else conflicts+=("$rel"); fi
    elif git merge-file -q -L "services/$name" -L "template (old)" -L "template (new)" "$ours" "$base" "$theirs"; then
      updated+=("$rel")
    else
      conflicts+=("$rel")
    fi
  done < <( (cd "$work/base" && find . -type f; cd "$work/theirs" && find . -type f) | sed 's|^\./||' | sort -u)

  $DRY_RUN || echo "$TARGET_REF" > "$svc/$TEMPLATE_REF_FILE"

  local label="synced"; $DRY_RUN && label="would sync"
  echo "[$name] $label ${base_ref:0:8} -> ${TARGET_REF:0:8}"
  local f
  for f in "${added[@]}";     do echo "    added     $f"; done
  for f in "${updated[@]}";   do echo "    updated   $f"; done
  for f in "${conflicts[@]}"; do echo "    CONFLICT  $f"; done
  for f in "${skipped[@]}";   do echo "    skipped   $f (deleted in the service)"; done
  for f in "${removed[@]}";   do echo "    removed from template, kept here: $f (delete it if no longer needed)"; done
  [ $(( ${#added[@]} + ${#updated[@]} + ${#conflicts[@]} + ${#removed[@]} )) -gt 0 ] || echo "    nothing to apply"
  [ ${#conflicts[@]} -eq 0 ] || CONFLICTS_FOUND=true
}

CONFLICTS_FOUND=false
FAILED=false
for name in "${NAMES[@]}"; do
  sync_one "$name" || FAILED=true
done

if ! $DRY_RUN; then
  echo
  echo "Review with: git diff -- services/"
  echo "Undo with  : git restore -- services/<name> && git clean -fd -- services/<name>"
  $CONFLICTS_FOUND && echo "Resolve the <<<<<<< / >>>>>>> markers in the CONFLICT files, then build and commit."
fi
$FAILED && exit 1
$CONFLICTS_FOUND && exit 2
exit 0