#!/usr/bin/env bash
set -euo pipefail

# Runtime v1 condition 9 (#1311): "every runtime contract has automated
# conformance tests." Per docs/superpowers/specs/2026-07-28-airo-mind-conformance-suite.md
# (tracked on #1340), the suite is S1-S5, one per contract C1/C2/C5/C6/C7 --
# and per that doc, "a conformance test that has to change when the storage
# engine changes was written against the implementation and is a unit test
# wearing the wrong label."
#
# Conformance tests for this suite land scattered across several PRs and,
# per this session's own briefing, two more are landing in parallel from
# other agents (#1217 purge/destroy, #1223 type system) whose file names this
# script cannot know in advance. So this is a *discovery* aggregator, not a
# hardcoded list: any file matching `rust/*/tests/*conformance*.rs` is a
# member of the suite, structurally, the same way `module.yaml` discovery
# works for the Engineering Council gate.
#
# This is the single entry point condition 9 needs: one command that finds
# every conformance test in the workspace, runs it, and reports which of the
# five lettered suites (S1-S5) currently has coverage -- so a suite silently
# having zero tests is visible instead of assumed.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CARGO_MANIFEST="rust/Cargo.toml"

if [[ ! -f "$CARGO_MANIFEST" ]]; then
  echo "FATAL: $CARGO_MANIFEST not found -- run from the repo root." >&2
  exit 1
fi

# --- Discover -----------------------------------------------------------
# Structural discovery: any tests/*conformance*.rs under any rust/ crate.
# Portable `find` piped into a `while read` loop rather than `mapfile` --
# `mapfile`/`readarray` need bash 4+, and macOS still ships bash 3.2 as
# `/bin/bash`, the same portability constraint the module-manifest and
# projection-route gates already work around.
conformance_files=()
while IFS= read -r f; do
  [[ -n "$f" ]] && conformance_files+=("$f")
done < <(
  find rust -type d -name tests -mindepth 2 -maxdepth 2 \
    -exec find {} -maxdepth 1 -type f -iname '*conformance*.rs' \; \
    2>/dev/null | sort
)

# Positive control. A `find` that silently matches nothing -- wrong path,
# renamed directory, moved crate -- would report "0 failures" having checked
# nothing, which is worse than failing loudly. The suite is known to have at
# least two files today (#1194/#1195, #1302); if discovery finds none, the
# discovery mechanism itself is broken, not the codebase.
if [[ ${#conformance_files[@]} -eq 0 ]]; then
  echo "FATAL: no rust/*/tests/*conformance*.rs files were discovered." >&2
  echo "This suite is known to have conformance tests today -- discovery is broken." >&2
  exit 1
fi

echo "Discovered ${#conformance_files[@]} conformance test file(s):"
for f in "${conformance_files[@]}"; do
  echo "  - $f"
done
echo

# --- Suite tag coverage ---------------------------------------------------
# Each conformance file's header comment names the suite(s) it proves, e.g.
# "contract `C6`, checklist `S4`". Extract that so a suite going to zero
# files is a visible line in the report, not something only a human auditing
# the spec doc by hand would notice.
#
# Plain variables, not an associative array: bash 3.2 (still `/bin/bash` on
# macOS) has no `declare -A`, the same constraint the discovery loop above
# works around.
echo "Suite coverage (S1-S5, per docs/superpowers/specs/2026-07-28-airo-mind-conformance-suite.md):"
missing_suites=()
for suite in S1 S2 S3 S4 S5; do
  matches=""
  for f in "${conformance_files[@]}"; do
    header="$(head -n 20 "$f")"
    if grep -qE "\`${suite}\`|checklist ${suite}\b" <<<"$header"; then
      matches+="$f "
    fi
  done
  if [[ -z "$matches" ]]; then
    echo "  $suite: NO CONFORMANCE FILE TAGS ITSELF WITH $suite"
    missing_suites+=("$suite")
  else
    echo "  $suite: $matches"
  fi
done
echo

if [[ ${#missing_suites[@]} -gt 0 ]]; then
  echo "WARNING: ${#missing_suites[@]} suite(s) have no tagged conformance test yet: ${missing_suites[*]}" >&2
  echo "Per condition 9, this is not a pass -- it is a known, visible gap. Non-blocking" >&2
  echo "here because some suites (S1/S5) depend on runtime surfaces (Vault) not yet" >&2
  echo "built on this branch; landing this gate is what makes the gap mechanical" >&2
  echo "instead of something only a council review would catch." >&2
  echo >&2
fi

# --- Run --------------------------------------------------------------
# One `cargo test` invocation per discovered crate, filtered to only the
# conformance test binaries so this doesn't silently widen into "run every
# test in the workspace" (that's rust-core.yml's separate, existing job).
failures=0
for f in "${conformance_files[@]}"; do
  # rust/<crate>/tests/<name>.rs -> crate=<crate>, test binary=<name>
  crate="$(echo "$f" | cut -d/ -f2)"
  name="$(basename "$f" .rs)"
  echo "== cargo test -p $crate --test $name =="
  if ! cargo test --manifest-path "$CARGO_MANIFEST" -p "$crate" --test "$name"; then
    echo "FAILED: $f" >&2
    failures=$((failures + 1))
  fi
  echo
done

if [[ $failures -gt 0 ]]; then
  echo "FATAL: $failures conformance test file(s) failed." >&2
  exit 1
fi

echo "All discovered conformance tests passed."
