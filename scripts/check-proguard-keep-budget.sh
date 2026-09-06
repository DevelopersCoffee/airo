#!/usr/bin/env bash
# =============================================================================
# ProGuard blanket-keep budget guard
# =============================================================================
# Fails when app/android/app/proguard-rules.pro gains a new blanket keep rule
# (`-keep class <pkg>.** { *; }` or `-keep public class <pkg>.** { *; }`) for
# a package that isn't already on the reviewed allowlist below.
#
# Why this exists: commit 65b0b2d5 dropped a blanket `-keep class
# androidx.** { *; }` that was the single largest driver of a low Play
# Console App Bundle Explorer optimization score -- every AndroidX artifact
# already ships its own consumer proguard rules, so keeping the whole tree
# blocked R8 shrinking/obfuscation across the dependency graph for no reason.
# This guard exists so the next dependency added under time pressure can't
# silently reintroduce that class of regression.
#
# The rules already in proguard-rules.pro are pre-approved (each one carries
# its own justification comment in that file already). A *new* blanket keep
# for a package not on ALLOWED_PACKAGES fails CI unless the line immediately
# above it is annotated `# keep-budget: allow` -- forcing a deliberate,
# reviewable opt-in instead of a silent copy-paste.
#
# Usage: ./scripts/check-proguard-keep-budget.sh
# Exit 0 on success, 1 when an unreviewed blanket keep is found.
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROGUARD_FILE="${AIRO_PROGUARD_FILE:-$ROOT_DIR/app/android/app/proguard-rules.pro}"

# Packages already blanket-kept in proguard-rules.pro as of the guard's
# introduction, each with its own in-file justification. Keep this list in
# sync with the file: removing a keep from the .pro file should also remove
# it here, so a *reintroduction* is caught like any other new entry.
ALLOWED_PACKAGES=(
  "io.flutter"
  "io.flutter.embedding"
  "io.flutter.plugins"
  "com.write4me.llama_flutter_android"
  "com.google.mlkit"
  "com.google.mlkit.genai"
  "com.google.firebase"
  "com.google.android.gms"
  "com.example.stockfish"
  "stockfish"
  "org.libsdl"
  "org.sqlite"
  "androidx.lifecycle"
  "com.dexterous.flutterlocalnotifications.models"
  "com.dexterous.flutterlocalnotifications.RuntimeTypeAdapterFactory"
)

fail() {
  echo "::error::$1" >&2
  exit 1
}

is_allowed() {
  local pkg="$1"
  local allowed
  for allowed in "${ALLOWED_PACKAGES[@]}"; do
    [[ "$pkg" == "$allowed" ]] && return 0
  done
  return 1
}

[[ -f "$PROGUARD_FILE" ]] || fail "ProGuard rules file not found: $PROGUARD_FILE"

errors=0
checked=0
prev_line=""

while IFS= read -r lineno_line; do
  lineno="${lineno_line%%:*}"
  content="${lineno_line#*:}"

  # Skip comment lines outright -- a `-keep` shape mentioned in prose (e.g.
  # documenting a blanket keep that was considered and rejected) is not a
  # live directive and must not trip the guard.
  if [[ "$content" =~ ^[[:space:]]*# ]]; then
    prev_line="$content"
    continue
  fi

  # Match `-keep class <pkg>.** { *; }` and `-keep public class <pkg>.** { *; }`,
  # the shape that keeps every member of every class under a package tree.
  if [[ "$content" =~ -keep[[:space:]]+(public[[:space:]]+)?class[[:space:]]+([A-Za-z0-9_.$]+)\.\*\*[[:space:]]*\{[[:space:]]*\*\;[[:space:]]*\} ]]; then
    pkg="${BASH_REMATCH[2]}"
    checked=$((checked + 1))

    if is_allowed "$pkg"; then
      echo "✓ proguard-rules.pro:$lineno pre-approved blanket keep for $pkg"
    elif [[ "$prev_line" == *"keep-budget: allow"* ]]; then
      echo "✓ proguard-rules.pro:$lineno new blanket keep for $pkg explicitly allowed (keep-budget: allow)"
    else
      echo "::error file=app/android/app/proguard-rules.pro,line=$lineno::Unreviewed blanket keep '-keep class $pkg.** { *; }'. Blanket package keeps block R8 shrinking/obfuscation across the whole tree and are the main driver of a low Play Console optimization score (see 65b0b2d5). Prefer a narrower -keep (specific classes/members), or if a blanket keep is genuinely required, add a '# keep-budget: allow' comment on the line above explaining why, and add '$pkg' to ALLOWED_PACKAGES in scripts/check-proguard-keep-budget.sh." >&2
      errors=$((errors + 1))
    fi
  fi

  prev_line="$content"
done < <(grep -n '' "$PROGUARD_FILE")

echo ""
if [[ "$errors" -gt 0 ]]; then
  echo "Found $errors unreviewed blanket ProGuard keep(s) in $PROGUARD_FILE."
  exit 1
fi

echo "ProGuard keep budget check passed ($checked blanket keep(s) inspected)."
