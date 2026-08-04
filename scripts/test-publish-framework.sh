#!/usr/bin/env bash
# Narrow contract check for tools/publish: byte-compile, unit tests, and a
# real dry-run plan against the repository's own publish config.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 -m compileall -q tools/publish >/dev/null
python3 -m unittest scripts.tests.test_publish_framework

# The committed config must load and every target must resolve to a publisher.
python3 -m tools.publish targets >/dev/null

echo "PASS: tools/publish"
