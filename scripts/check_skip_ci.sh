#!/usr/bin/env bash
# Reject `[skip ci]` on commits that touch executable behaviour.
#
# Usage:
#   scripts/check_skip_ci.sh <commit-msg-file> [<file>...]
#
# With no file list, reads the staged file list (`git diff --cached --name-only`).
# Exits 0 when the commit is allowed, 1 when `[skip ci]` must be removed.
#
# Why this exists: on 2026-07-29 commit c2ada89f renamed a UI string, shipped
# with [skip ci], and left a test in app/ asserting the old string. Nothing ran,
# so main went red on the next unrelated push. See docs/agents/WORKFLOW.md
# "Skipping CI".
set -euo pipefail

MSG_FILE="${1:-}"
if [ -z "$MSG_FILE" ] || [ ! -f "$MSG_FILE" ]; then
  echo "usage: ${BASH_SOURCE[0]##*/} <commit-msg-file> [<file>...]" >&2
  exit 2
fi

# Only care about commits that actually ask to skip CI.
if ! grep -qiE '\[(skip ci|ci skip)\]' "$MSG_FILE"; then
  exit 0
fi

shift || true
if [ "$#" -gt 0 ]; then
  FILES="$(printf '%s\n' "$@")"
else
  FILES="$(git diff --cached --name-only)"
fi

[ -n "$FILES" ] || exit 0

# Paths whose contents change what the app or the build does. A commit touching
# any of these must be validated by CI, so it may not carry [skip ci].
is_executable_path() {
  case "$1" in
    *.md|*.txt|LICENSE|AUTHORS|CHANGELOG*) return 1 ;;
    docs/*|.github/ISSUE_TEMPLATE/*|.github/PULL_REQUEST_TEMPLATE.md) return 1 ;;
    .github/workflows/*) return 0 ;;
    app/*|packages/*|packages_pro/*|rust/*|e2e/*|tool/*|scripts/*) return 0 ;;
    Makefile|melos.yaml|analysis_options.yaml|*.gradle|*.gradle.kts) return 0 ;;
    *pubspec.yaml|*pubspec.lock|*pubspec_overrides.yaml) return 0 ;;
    Cargo.toml|Cargo.lock|*/Cargo.toml|*/Cargo.lock) return 0 ;;
    *.dart|*.rs|*.kt|*.java|*.swift|*.sh|*.py|*.ts|*.js) return 0 ;;
    *) return 1 ;;
  esac
}

OFFENDERS=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if is_executable_path "$f"; then
    OFFENDERS="${OFFENDERS}  ${f}"$'\n'
  fi
done <<< "$FILES"

[ -n "$OFFENDERS" ] || exit 0

cat >&2 <<EOF
Refusing [skip ci]: this commit changes executable behaviour.

$OFFENDERS
[skip ci] is for documentation, comments, markdown, issue/PR templates, and
other non-executable metadata. Anything under app/, packages/, rust/, scripts/,
e2e/, the build files, or .github/workflows/ has to be proven by a CI run.

Remove [skip ci] from the message, or move the executable changes to their own
commit. See docs/agents/WORKFLOW.md "Skipping CI".
EOF
exit 1
