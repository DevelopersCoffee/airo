#!/bin/bash
# L1.2 — ENUMERABLE OBLIGATIONS.
#
# Every obligation here answers YES to: "can I enumerate the complete universe
# of things this applies to?" Each is checked by scanning the WHOLE crate for
# the construct class and diffing against an allowlist of approved exceptions.
#
# WHY THESE MOVED OUT OF L2. They were L2 greps that named a file, and both of
# the findings that escaped Revision 9B are what that costs:
#
#   SEC-49  is A12's exact subject -- an unchecked increment -- at a SECOND
#           site. A12 greps package.rs; the second site is revocation.rs:142.
#   SEC-47  is A04's exact subject -- a raw identifier -- on a SECOND identifier
#           kind. A04b greps for context_id; content_id and device_id are raw.
#
# Neither is a new defect class. Both are the same obligation, unguarded where
# the assertion did not happen to look:
#
#     invariant enforced at site A -> assertion written for site A
#         -> invariant appears at site B -> assertion never generalized
#
# That is a LOCALITY problem, not a pattern-quality problem. Tightening the
# regex does not move an assertion pinned to where the obligation was first
# observed. The remedy is to check the complete universe and allowlist the
# exceptions, so a new site fails by default rather than passing by omission.
#
# Usage:
#   bash docs/superpowers/plans/g0-enumerable.sh [crate-src-dir]
#   bash docs/superpowers/plans/g0-enumerable.sh --record
set -u
SP=/private/tmp/claude-501/-Users-udaychauhan-workspace-airo/e1fc7091-9136-4c43-b3e5-8187b71864a4/scratchpad
HERE="$(cd "$(dirname "$0")" && pwd)"
ALLOW_DIR="$HERE/enumerable"
RECORD=0
if [ "${1:-}" = "--record" ]; then RECORD=1; shift; fi
SRC="${1:-$SP/rev7/src}"

# L0 preconditions. Without these every scan returns empty and passes.
if [ ! -d "$SRC" ]; then
  echo "L1.2: ABORT -- source tree not found: $SRC" >&2
  exit 2
fi
n_rs=$(find "$SRC" -name '*.rs' | wc -l | tr -d ' ')
if [ "$n_rs" -lt 10 ]; then
  echo "L1.2: ABORT -- only $n_rs .rs files under $SRC; expected the full crate" >&2
  exit 2
fi

mkdir -p "$ALLOW_DIR"
TOTAL_NEW=0

# scan ID DESC PATTERN
# Emits `file :: matched-text`, line numbers stripped so a shifted line is not
# a diff. Test modules are NOT excluded: a test is code, and SEC-50 showed
# controls can be removed while tests stay green.
scan() {
  local id="$1" desc="$2" pat="$3"
  local allow="$ALLOW_DIR/$id.txt"
  local actual
  actual=$(grep -rnE --include='*.rs' -e "$pat" "$SRC" 2>/dev/null \
    | sed "s|^$SRC/||" \
    | sed -E 's/^([^:]+):[0-9]+:[[:space:]]*(.*)$/\1 :: \2/' \
    | sed -E 's/[[:space:]]+$//' \
    | sort -u)

  if [ "$RECORD" -eq 1 ]; then
    printf '%s\n' "$actual" > "$allow"
    local n; n=$(printf '%s\n' "$actual" | grep -c . || true)
    printf '  recorded %-3s sites  %s\n' "$n" "$id"
    return
  fi

  [ -f "$allow" ] || : > "$allow"
  local added
  added=$(comm -13 "$allow" <(printf '%s\n' "$actual"))
  local n_added; n_added=$(printf '%s\n' "$added" | grep -c . || true)

  if [ "$n_added" -gt 0 ]; then
    printf '  FAIL  %-14s %s\n' "$id" "$desc"
    printf '%s\n' "$added" | grep . | sed 's/^/          + /'
    TOTAL_NEW=$((TOTAL_NEW + n_added))
  else
    local n; n=$(grep -c . "$allow" || true)
    printf '  PASS  %-14s %s  (%s allowlisted)\n' "$id" "$desc" "$n"
  fi
}

if [ "$RECORD" -eq 1 ]; then
  echo "L1.2 recording enumerable obligations -- $SRC"
else
  echo "L1.2 enumerable obligations -- $SRC"
fi
echo

# Every arithmetic mutation that can wrap. SEC-49: the second site.
scan unchecked-arith 'no unchecked += / -= / * on integers' \
  '[a-z_.]+ (\+=|-=) [0-9]'

# Every public entry point taking a raw identifier. SEC-47: the second kind.
scan raw-identifier 'no raw identifier at a public entry point' \
  'pub fn [a-z_]+\(&?m?u?t? ?self,? ?[a-z_]*(content_id|context_id|device_id|subject_id): &str'

# Every RNG call site. RA-3: the one obligation that stayed fixed, because it
# was already checked this way.
scan rng-sites 'OsRng appears only in random.rs' \
  'OsRng'

# Every per-byte hex formatting. RA-24: A10 saw one spelling; this sees any.
scan per-byte-hex 'no per-byte hex formatting' \
  'format!\("\{[^"]*:02x\}"'

echo
if [ "$RECORD" -eq 1 ]; then
  echo "REVIEW EVERY LINE. Each allowlisted site is an approved exception."
  exit 0
fi
if [ "$TOTAL_NEW" -gt 0 ]; then
  printf 'L1.2: FAILED -- %s site(s) not in an allowlist\n' "$TOTAL_NEW"
  echo
  echo "A new site is the SAME obligation appearing somewhere new. That is how"
  echo "SEC-47 and SEC-49 reached a shipped revision: the assertion was pinned"
  echo "to where the obligation was first observed."
  exit 1
fi
echo "L1.2: PASS -- every enumerated site is allowlisted"
