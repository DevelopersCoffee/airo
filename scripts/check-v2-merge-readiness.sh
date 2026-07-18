#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

base_ref="origin/main"
next_ref="origin/codex/next-v2.0.0.0"
skip_fetch=false
keep_worktree=false
worktree_dir=""

usage() {
  cat <<'EOF'
Usage: check-v2-merge-readiness.sh [options]

Locally dry-merge the rolling next development branch into the main base line,
then run cheap structural checks. This command does not push, commit, dispatch
workflows, publish releases, or upload artifacts.

Options:
  --base <ref>          Base ref to dry-merge into. Default: origin/main
  --next <ref>          Rolling next ref to dry-merge. Default: origin/codex/next-v2.0.0.0
  --worktree <path>     Use this worktree path instead of a temporary directory
  --skip-fetch          Do not fetch origin before checking refs
  --keep-worktree       Keep the dry-run worktree after the script exits
  -h, --help            Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      base_ref="${2:-}"
      shift 2
      ;;
    --next)
      next_ref="${2:-}"
      shift 2
      ;;
    --worktree)
      worktree_dir="${2:-}"
      shift 2
      ;;
    --skip-fetch)
      skip_fetch=true
      shift
      ;;
    --keep-worktree)
      keep_worktree=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$base_ref" || -z "$next_ref" ]]; then
  echo "--base and --next must be non-empty refs." >&2
  exit 2
fi

cd "$ROOT_DIR"

if [[ "$skip_fetch" == "false" ]]; then
  git fetch origin main v1_bkp codex/next-v2.0.0.0
fi

if ! git rev-parse --verify "$base_ref" >/dev/null 2>&1; then
  echo "Base ref does not exist: $base_ref" >&2
  exit 2
fi

if ! git rev-parse --verify "$next_ref" >/dev/null 2>&1; then
  echo "Next ref does not exist: $next_ref" >&2
  exit 2
fi

base_oid="$(git rev-parse "$base_ref")"
next_oid="$(git rev-parse "$next_ref")"

if [[ -z "$worktree_dir" ]]; then
  worktree_dir="$(mktemp -d "${TMPDIR:-/tmp}/airo-main-merge-readiness.XXXXXX")"
  rmdir "$worktree_dir"
else
  mkdir -p "$(dirname "$worktree_dir")"
fi

created_worktree=false
cleanup() {
  local exit_code=$?
  if [[ "$created_worktree" == "true" && -e "$worktree_dir/.git" ]]; then
    (
      cd "$worktree_dir"
      if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
        git merge --abort >/dev/null 2>&1 || true
      fi
    )
  fi
  if [[ "$keep_worktree" == "false" && "$created_worktree" == "true" ]]; then
    git -C "$ROOT_DIR" worktree remove --force "$worktree_dir" >/dev/null 2>&1 || true
  fi
  exit "$exit_code"
}
trap cleanup EXIT

git worktree add --detach "$worktree_dir" "$base_oid" >/dev/null
created_worktree=true

base_sha="$(git rev-parse --short "$base_oid")"
next_sha="$(git rev-parse --short "$next_oid")"

echo "Airo mainline merge-readiness dry run"
echo "Base: $base_ref ($base_sha)"
echo "Next: $next_ref ($next_sha)"
echo "Worktree: $worktree_dir"

cd "$worktree_dir"

if ! git merge --no-commit --no-ff "$next_oid"; then
  echo "Dry merge failed. Resolve conflicts before merging rolling next into main." >&2
  git status --short >&2 || true
  exit 1
fi

changed_count="$(git diff --cached --name-only | wc -l | tr -d ' ')"
echo "Dry merge staged files: $changed_count"

ruby -e "require 'yaml'; YAML.load_file('melos.yaml'); YAML.load_file('pubspec.yaml')"
echo "YAML parse: ok"

git diff --cached --check
echo "Whitespace check: ok"

readiness_output="$(mktemp "${TMPDIR:-/tmp}/airo-v2-readiness.XXXXXX")"
set +e
(
  cd packages/core_release
  dart run tool/preflight_v2_release_readiness.dart
) >"$readiness_output" 2>&1
readiness_exit=$?
set -e

if [[ "$readiness_exit" -eq 0 ]]; then
  echo "V2 readiness preflight: publicReady=true"
else
  if grep -q '"publicReady": false' "$readiness_output"; then
    echo "V2 readiness preflight: unresolved gates remain"
  else
    echo "V2 readiness preflight failed unexpectedly:" >&2
    cat "$readiness_output" >&2
    exit "$readiness_exit"
  fi
fi
rm -f "$readiness_output"

echo "Merge readiness dry run completed without structural failures."
