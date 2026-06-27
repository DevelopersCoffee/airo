#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-docs-completeness.sh [--base <ref>] [--head <ref>]

Fails when user-visible feature changes are present without a matching
docs/wiki update, unless an explicit docs bypass is declared.

Bypass options:
- set AIRO_DOCS_BYPASS=true
- include "docs-not-needed" in a commit message within the diff range
EOF
}

base_ref=""
head_ref="HEAD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      base_ref="${2:-}"
      shift 2
      ;;
    --head)
      head_ref="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$base_ref" ]]; then
  if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
    base_ref="HEAD~1"
  else
    echo "Unable to infer a base ref. Pass --base <ref>." >&2
    exit 2
  fi
fi

if ! git rev-parse --verify "$base_ref" >/dev/null 2>&1; then
  echo "Base ref does not exist: $base_ref" >&2
  exit 2
fi

if ! git rev-parse --verify "$head_ref" >/dev/null 2>&1; then
  echo "Head ref does not exist: $head_ref" >&2
  exit 2
fi

range="$base_ref...$head_ref"
changed_files=()
while IFS= read -r file; do
  changed_files+=("$file")
done < <(git diff --name-only "$range")

if [[ ${#changed_files[@]} -eq 0 ]]; then
  echo "No changed files detected for $range."
  exit 0
fi

if [[ "${AIRO_DOCS_BYPASS:-false}" == "true" ]]; then
  echo "Docs completeness bypassed via AIRO_DOCS_BYPASS=true."
  exit 0
fi

if git log --format=%B "$range" | grep -qi 'docs-not-needed'; then
  echo "Docs completeness bypassed via commit message marker."
  exit 0
fi

triggered_files=()
wiki_touched=false

for file in "${changed_files[@]}"; do
  case "$file" in
    docs/wiki/*)
      wiki_touched=true
      ;;
    app/lib/features/*|app/lib/core/routing/*|README.md)
      triggered_files+=("$file")
      ;;
  esac
done

if [[ ${#triggered_files[@]} -eq 0 ]]; then
  echo "No docs-gated feature changes detected."
  exit 0
fi

if [[ "$wiki_touched" == "true" ]]; then
  echo "docs/wiki updated alongside docs-gated feature changes."
  exit 0
fi

echo "docs/wiki update required for these changed files:" >&2
for file in "${triggered_files[@]}"; do
  echo "  - $file" >&2
done
echo >&2
echo "Add a matching docs/wiki update, apply a docs-not-needed PR label," >&2
echo "or include 'docs-not-needed' in the commit message when the bypass is intentional." >&2
exit 1
