#!/usr/bin/env bash
set -euo pipefail

# Rule R05: Airo Mind renders only on a device one person owns.
#
# Web and TV are shared surfaces. Mind is absent from those binaries, not
# disabled inside them -- a runtime flag can be flipped, an absent package
# cannot be reached. This gate asserts the shared-surface flavors do not link
# the real feature_mind.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Positive control. This gate's whole job is to find something that should not
# be there, so a broken search reports OK having checked nothing. Prove the
# search works against a file that must exist before trusting a clean result.
if ! grep -q 'name: feature_mind' packages/stubs/feature_mind_stub/pubspec.yaml 2>/dev/null; then
  echo "FATAL: could not read the feature_mind stub's pubspec, so this gate" >&2
  echo "cannot verify anything. Passing silently would be worse than failing." >&2
  exit 127
fi

# Pubspecs whose builds reach a screen other people can see.
shared_pubspecs=("app/pubspec_tv.yaml")

failed=false

for pubspec in "${shared_pubspecs[@]}"; do
  [[ -f "$pubspec" ]] || continue

  if grep -qE '^[[:space:]]+feature_mind:' "$pubspec"; then
    # A dependency is only acceptable when the same flavor points it at the
    # stub, either inline or through its own overrides file.
    overrides="${pubspec%.yaml}_overrides.yaml"
    if grep -q 'feature_mind_stub' "$pubspec"; then
      continue
    fi
    if [[ -f "$overrides" ]] && grep -q 'feature_mind_stub' "$overrides"; then
      continue
    fi
    failed=true
    echo "R05 violation: $pubspec links feature_mind with no stub swap." >&2
  fi
done

# The web build uses app/pubspec.yaml, where Mind is a legitimate dependency
# for the phone and desktop targets. The check for web is therefore on the
# sources a web build compiles: nothing under app/web may reach the module.
if [[ -d "app/web" ]]; then
  web_imports="$(
    grep -rn --include='*.dart' -e "package:feature_mind/" app/web 2>/dev/null || true
  )"
  if [[ -n "$web_imports" ]]; then
    failed=true
    echo "R05 violation: web sources import feature_mind." >&2
    echo "$web_imports" >&2
  fi
fi

if [[ "$failed" == true ]]; then
  cat >&2 <<'EOF'

A personal vault must not render on a screen other people use. Swap in
packages/stubs/feature_mind_stub through pubspec_overrides.yaml rather than
hiding the module at runtime -- a runtime flag can be flipped, an absent
package cannot be reached.
EOF
  exit 1
fi

echo "R05 OK: no shared-surface flavor links feature_mind."
