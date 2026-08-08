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

if grep -q 'package:feature_mind/' "$web_entrypoint"; then
  failed=true
  echo "R05 violation: $web_entrypoint imports package:feature_mind, so a web" >&2
  echo "build reaches the real module straight from the entrypoint." >&2
fi

# The entrypoint delegates registration to a `dart.library` seam, so the check
# above now passes by the module simply not being named there. That is the
# intended shape -- and on its own it would rot into the same "reported OK
# having checked nothing" failure the app/web grep had, because the file the
# WEB compile actually picks would go unexamined. So follow the seam.
#
# Two halves, and this gate cares about exactly one of them: the
# `if (dart.library.html)` variant, which is what a web compile picks. The
# default variant is the private-device build and is *supposed* to name
# MindModule, so checking it would fail on a correct tree.
#
# CAVEAT, recorded rather than silently "fixed": `dart.library.html` is false
# under dart2wasm, so `flutter build web --wasm` would resolve the DEFAULT
# half -- the real module -- and link Mind into a shared surface. That is
# latent today (the wasm dry run already reports dart:ffi blockers, so wasm
# cannot build here at all) and this gate cannot observe it, because the
# condition is resolved by the compiler, not by any text this script can read
# on its own. Inverting the seam to `stub-by-default, if (dart.library.io)
# real` closes it without changing either file's contents. See #1565.
web_registration="app/lib/core/mind/mind_registration_stub.dart"

# Positive control #1: the entrypoint must still route through the seam. A
# `registerMind(` call that was deleted, renamed, or replaced by an
# inline registration in some other file leaves this gate inspecting a file
# nothing imports.
if ! grep -q 'mind_registration_stub.dart' "$web_entrypoint" ||
   ! grep -q 'registerMind(' "$web_entrypoint"; then
  echo "FATAL: $web_entrypoint no longer registers Mind through the" >&2
  echo "$web_registration seam, so this gate would be checking a file the" >&2
  echo "web build does not use. Passing silently would be worse than" >&2
  echo "failing." >&2
  exit 127
fi

# Positive control #2: prove the search can read the seam's web half before
# trusting it to find nothing there.
if ! grep -q 'void registerMind(' "$web_registration" 2>/dev/null; then
  echo "FATAL: could not find registerMind in $web_registration, so" >&2
  echo "this gate cannot tell what a web build links. Passing silently would" >&2
  echo "be worse than failing." >&2
  exit 127
fi

if grep -q 'package:feature_mind/' "$web_registration"; then
  failed=true
  echo "R05 violation: $web_registration imports package:feature_mind, so a" >&2
  echo "web build links the real module through the registration seam." >&2
fi

if grep -qE '(^|[^_[:alnum:]])MindModule\(' "$web_registration"; then
  failed=true
  echo "R05 violation: $web_registration constructs MindModule, so a web" >&2
  echo "build composes Mind into a shared surface." >&2
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
