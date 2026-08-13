#!/usr/bin/env bash
set -euo pipefail

# Rejects the unsafe inverted conditional-import pattern:
#
#   import 'real.dart' if (dart.library.html) 'stub.dart';
#
# `dart.library.html` is false under dart2wasm (wasm has no dart:html), so
# this shape resolves to the DEFAULT branch -- the "real" (dart:io/ffi-backed,
# native) implementation -- for a wasm web compile. That leaks native code
# into a web build instead of falling back to the web-safe stub.
#
# The safe, documented convention (see `app/lib/main.dart`) is stub-by-default:
#
#   import 'stub.dart' if (dart.library.io) 'real.dart';
#
# `dart.library.io` is only true on native platforms, so both js web and wasm
# web fall back to the stub. See `scripts/check-mind-private-devices.sh` for
# the prose this hazard was first documented against (#1565, #1679).
#
# This gate greps for the unsafe token in real import/export continuation
# lines -- `if (dart.library.html)` at the start of a (possibly indented)
# line -- not for the string anywhere in the file, so prose comments
# discussing the hazard (like this file, or `app/lib/main.dart`) do not
# trip it.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Positive control. This gate's whole job is to find something that should
# not be there, so a broken search reports OK having checked nothing. Prove
# the search works against a pattern that must match before trusting a clean
# result.
positive_control="$(printf "import 'a.dart'\n    if (dart.library.html) 'b.dart';\n" |
  grep -E '^[[:space:]]*if[[:space:]]*\(dart\.library\.html\)' || true)"
if [[ -z "$positive_control" ]]; then
  echo "FATAL: the grep pattern used by this gate did not match a known-bad" >&2
  echo "sample, so it cannot be trusted to find real violations either." >&2
  echo "Passing silently would be worse than failing." >&2
  exit 127
fi

pattern='^[[:space:]]*if[[:space:]]*\(dart\.library\.html\)'
matches="$(grep -rnE "$pattern" --include='*.dart' . || true)"

if [[ -n "$matches" ]]; then
  echo "Unsafe dart.library.html conditional import(s) found:" >&2
  echo "$matches" >&2
  cat >&2 <<'EOF'

`dart.library.html` is false under dart2wasm, so `import 'real.dart' if
(dart.library.html) 'stub.dart'` resolves to the REAL (native/io/ffi) branch
on a wasm web build -- the opposite of what is intended. Flip to
stub-by-default: `import 'stub.dart' if (dart.library.io) 'real.dart';`,
matching the convention documented in app/lib/main.dart.

If a file genuinely needs to key off `dart:html` specifically (not
`dart:io`/ffi) -- e.g. an implementation that only works under classic
dart2js -- keep the stub as the default branch and gate on a token other than
`dart.library.html` (see packages/feature_iptv/lib/presentation/utils/
web_fullscreen.dart for a worked example using `dart.library.js`).
EOF
  exit 1
fi

echo "OK: no unsafe dart.library.html conditional imports found."
