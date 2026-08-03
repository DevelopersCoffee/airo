#!/usr/bin/env bash
set -euo pipefail

# Rule R03: graph, timeline and search are one switcher, never three
# destinations. A widget cannot enforce that on its own -- someone can always
# add a GoRoute for one of them -- so this gate checks the routes.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Portable POSIX grep, not ripgrep. GitHub's ubuntu-latest runner does not ship
# rg, and a gate that only runs on a developer laptop is not a gate.
scan() {
  grep -rnE \
    --include='*.dart' \
    --exclude-dir=test \
    --exclude-dir=cargokit \
    --exclude-dir=build \
    -e "$1" \
    "${scan_paths[@]}" 2>/dev/null || true
}

scan_paths=()
for path in "app/lib" "packages"; do
  [[ -e "$path" ]] && scan_paths+=("$path")
done

if [[ ${#scan_paths[@]} -eq 0 ]]; then
  echo "No Dart sources to scan." >&2
  exit 1
fi

# Positive control. A `|| true` search that silently finds nothing -- missing
# tool, wrong flags, wrong paths -- would report OK having checked nothing,
# which is the exact failure this gate exists to prevent. So first prove the
# search finds a string we know is there.
if [[ -z "$(scan 'class MindProjectionSwitcher')" ]]; then
  echo "FATAL: the search found no MindProjectionSwitcher, which must exist." >&2
  echo "This gate cannot verify anything, and passing silently would be worse" >&2
  echo "than failing. Check grep availability and the scan paths." >&2
  exit 127
fi

violations="$(
  {
    scan "path:[[:space:]]*'/?(mind/)?(graph|timeline|search)'"
    scan "name:[[:space:]]*'(mind_)?(graph|timeline|search)'"
  } | sort -u
)"

if [[ -n "$violations" ]]; then
  cat >&2 <<'EOF'
Rule R03 violation: a route targets a single projection.

Graph, timeline and search are three views of one log, reached through
MindProjectionSwitcher on one screen. Routing to them separately teaches a
person they are three features that share data, which is the opposite of what
the runtime is.

EOF
  echo "$violations" >&2
  exit 1
fi

echo "R03 OK: no route targets a single projection."
