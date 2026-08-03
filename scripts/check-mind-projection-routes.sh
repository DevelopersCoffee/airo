#!/usr/bin/env bash
set -euo pipefail

# Rule R03: graph, timeline and search are one switcher, never three
# destinations. A widget cannot enforce that on its own -- someone can always
# add a GoRoute for one of them -- so this gate checks the routes.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Both gates locate violations with ripgrep inside `|| true`, so a missing rg
# would return no matches and the gate would pass having checked nothing. That
# is the exact failure this file exists to prevent, so refuse to run instead.
if ! command -v rg >/dev/null 2>&1; then
  echo "FATAL: ripgrep (rg) is not installed. This gate cannot verify anything" >&2
  echo "without it, and passing silently would be worse than failing." >&2
  exit 127
fi

scan_paths=()
for path in "app/lib" "packages"; do
  [[ -e "$path" ]] && scan_paths+=("$path")
done

if [[ ${#scan_paths[@]} -eq 0 ]]; then
  echo "No Dart sources to scan."
  exit 0
fi

violations="$(
  rg -n \
    --glob '*.dart' \
    --glob '!**/test/**' \
    --glob '!**/cargokit/**' \
    -e "path:\s*'/?(mind/)?(graph|timeline|search)'" \
    -e "name:\s*'(mind_)?(graph|timeline|search)'" \
    "${scan_paths[@]}" || true
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
