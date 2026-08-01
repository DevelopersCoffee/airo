#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for workflow in \
  "$ROOT_DIR/.github/workflows/airo-tv-release.yml" \
  "$ROOT_DIR/.github/workflows/airo-mobile-tablet-release.yml"; do
  grep -q 'id-token: write' "$workflow"
  grep -q 'attestations: write' "$workflow"
  grep -q 'artifact-metadata: write' "$workflow"
  grep -q 'uses: actions/attest@v4' "$workflow"
  grep -q 'subject-path: release-artifacts/\\*' "$workflow"
done

echo "Android release provenance contract passed"
