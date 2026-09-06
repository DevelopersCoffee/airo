#!/usr/bin/env bash
# Single source of truth for the Aika Stream (Airo TV) Android version.
#
# `app/pubspec_tv.yaml`'s `version:` field is the only place a human edits
# this number. Everything else must be derived from it:
#   - the TV package_info_plus stub (packages/stubs/package_info_plus_stub)
#     hardcodes a copy for the "App version" row on TV, since the real
#     plugin isn't wired for this flavor -- drifted from 13 to 14 once
#     already (see tv_stub_version_test.dart).
#   - Android's real versionName/versionCode always come from whichever
#     pubspec.yaml Flutter reads (`app/pubspec.yaml`, the phone app's own
#     version), NOT pubspec_tv.yaml -- `--target=lib/main_tv.dart` only
#     picks the Dart entrypoint, it does not swap pubspecs. Any TV build
#     that omits --build-name/--build-number silently stamps the phone
#     app's version into the TV APK's native metadata.
#
# Usage:
#   scripts/aika_stream_version.sh            # prints shell exports to stdout
#   eval "$(scripts/aika_stream_version.sh)"  # then use $AIKA_STREAM_BUILD_NAME /
#                                              # $AIKA_STREAM_BUILD_NUMBER
#   scripts/aika_stream_version.sh --sync-stub  # also rewrites the stub file
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC="$ROOT/app/pubspec_tv.yaml"
STUB="$ROOT/packages/stubs/package_info_plus_stub/lib/package_info_plus.dart"

VERSION_LINE="$(grep -E '^version:' "$PUBSPEC")"
FULL_VERSION="$(echo "$VERSION_LINE" | sed -E 's/^version:[[:space:]]*//')"
BUILD_NAME="${FULL_VERSION%%+*}"
BUILD_NUMBER="${FULL_VERSION##*+}"

if [ -z "$BUILD_NAME" ] || [ -z "$BUILD_NUMBER" ] || [ "$BUILD_NAME" = "$BUILD_NUMBER" ]; then
  echo "error: could not parse '$VERSION_LINE' from $PUBSPEC as <name>+<number>" >&2
  exit 1
fi

if [ "${1:-}" = "--sync-stub" ]; then
  python3 - "$STUB" "$BUILD_NAME" "$BUILD_NUMBER" <<'PYEOF'
import re
import sys

stub_path, build_name, build_number = sys.argv[1:4]
with open(stub_path, "r", encoding="utf-8") as f:
    text = f.read()

text, n1 = re.subn(
    r"const String _stubVersion = '[^']*';",
    f"const String _stubVersion = '{build_name}';",
    text,
)
text, n2 = re.subn(
    r"const String _stubBuildNumber = '[^']*';",
    f"const String _stubBuildNumber = '{build_number}';",
    text,
)
if n1 != 1 or n2 != 1:
    sys.exit(
        f"error: expected exactly one _stubVersion and one _stubBuildNumber "
        f"constant in {stub_path}, found {n1} and {n2}"
    )

with open(stub_path, "w", encoding="utf-8") as f:
    f.write(text)
print(f"synced {stub_path} -> {build_name}+{build_number}", file=sys.stderr)
PYEOF
fi

echo "export AIKA_STREAM_BUILD_NAME=$BUILD_NAME"
echo "export AIKA_STREAM_BUILD_NUMBER=$BUILD_NUMBER"
