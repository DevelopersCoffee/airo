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

# The web build uses app/pubspec.yaml, where Mind is a legitimate dependency for
# the phone and desktop targets. So the web check cannot be "is feature_mind a
# dependency" -- it has to be "does a web build REACH the module".
#
# This check used to grep `app/web` for `package:feature_mind/` imports.
# `app/web` holds index.html, the manifest and icons: it has never contained a
# single .dart file, so that search could not fail for any state of the
# repository. It reported OK having checked nothing, which is the exact failure
# the positive control above exists to prevent -- and the web half had no
# positive control of its own.
#
# The real question is the entrypoint's module registry. `app/lib/main.dart` is
# what a web build compiles, and registering MindModule there puts Mind in the
# web binary.
web_entrypoint="app/lib/main.dart"

# Positive control, same reasoning as above: prove the search can find
# something before trusting it to find nothing.
if ! grep -q 'ModuleRegistry' "$web_entrypoint" 2>/dev/null; then
  echo "FATAL: could not find a module registry in $web_entrypoint, so this" >&2
  echo "gate cannot tell what a web build links. Passing silently would be" >&2
  echo "worse than failing." >&2
  exit 127
fi

if grep -qE '(^|[^_[:alnum:]])MindModule\(' "$web_entrypoint"; then
  # Acceptable only when the same pubspec points feature_mind at the stub, so
  # the symbol resolves to a module that renders nothing.
  if ! { grep -q 'feature_mind_stub' app/pubspec.yaml 2>/dev/null ||
         { [[ -f app/pubspec_overrides.yaml ]] &&
           grep -q 'feature_mind_stub' app/pubspec_overrides.yaml; }; }; then
    failed=true
    echo "R05 violation: $web_entrypoint registers MindModule and no stub swap" >&2
    echo "is in place, so a web build links the real feature_mind." >&2
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
