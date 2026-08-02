#!/bin/bash
# G0.9 — PUBLIC SURFACE ALLOWLIST.
#
# Replaces the polarity of G0.7. G0.7 enumerates KNOWN DEFECTS by name; this
# enumerates APPROVED SURFACE and fails on anything else.
#
# Why the polarity had to invert. Rust Architect added nine characters to
# seed.rs on Revision 9B:
#
#     pub fn material(&self) -> &[u8; 32 * 2] { &self.0 }
#
# and the result passed `cargo clippy -D warnings`, G0.7 23/23, and G0.8 9/9,
# while an external consumer printed the 64-byte master seed. A01 greps for
# `pub fn as_bytes(&self) -> &[u8; 64]`; the G0.8 DENY probe compiles
# `seed.as_bytes()`. Both are pinned to a NAME, and the defect they guard has
# no dependence on that name.
#
# Their mutation table: of seven assertions tested by reintroducing the exact
# defect each names, ONE failed. A04b passed when `destroy_context` was reverted
# to `&str`, because rustfmt wraps that signature across four lines. A10 passed
# on `format!("{:02x}", b)` -- the same 21x regression, different spelling.
#
# So G0.7 is a mechanical record of Revision 8's spellings, which is RA-29's
# defect class -- an assertion that cannot fail -- relocated into the mechanism
# built to cure it.
#
# What this gate proves, and what it does not. It is a SYNTACTIC check on a
# COMPLETE enumeration: every `pub` item under src/ must appear in the reviewed
# allowlist. That catches additions regardless of name, which is the property
# the per-finding greps could not express. It does NOT prove reachability --
# G0.8 does that -- and it does not prove an approved item is correctly
# implemented.
#
# Usage:
#   bash docs/superpowers/plans/g0-public-surface.sh [crate-src-dir]
#   bash docs/superpowers/plans/g0-public-surface.sh --record   # regenerate
set -u
SP=/private/tmp/claude-501/-Users-udaychauhan-workspace-airo/e1fc7091-9136-4c43-b3e5-8187b71864a4/scratchpad
HERE="$(cd "$(dirname "$0")" && pwd)"
ALLOW="$HERE/PUBLIC_SURFACE.txt"
RECORD=0
if [ "${1:-}" = "--record" ]; then RECORD=1; shift; fi
SRC="${1:-$SP/rev7/src}"

# Same precondition as G0.7, and it was found here first: this script recorded
# ZERO public items and reported PASS against a scratch tree that had been
# cleaned. An allowlist gate whose "actual" side is empty passes everything.
if [ ! -d "$SRC" ]; then
  echo "G0.9: ABORT -- source tree not found: $SRC" >&2
  exit 2
fi
n_rs=$(find "$SRC" -name '*.rs' | wc -l | tr -d ' ')
if [ "$n_rs" -lt 10 ]; then
  echo "G0.9: ABORT -- only $n_rs .rs files under $SRC; expected the full crate" >&2
  exit 2
fi

# Every `pub` item that is not `pub(...)`-restricted, normalised to
# `file :: kind name`. Signatures are deliberately dropped: a rename must fail
# this gate, and so must an arity change, but a rustfmt line-wrap must not.
surface() {
  grep -rn --include='*.rs' -E '^[[:space:]]*pub (fn|struct|enum|trait|const|static|mod|use|type) ' "$SRC" \
    | grep -v 'pub(' \
    | sed "s|^$SRC/||" \
    | sed -E 's/^([^:]+):[0-9]+:[[:space:]]*pub (fn|struct|enum|trait|const|static|mod|use|type) ([A-Za-z0-9_]+).*/\1 :: \2 \3/' \
    | sort -u
}

if [ "$RECORD" -eq 1 ]; then
  surface > "$ALLOW"
  echo "recorded $(wc -l < "$ALLOW" | tr -d ' ') public items to $ALLOW"
  echo "REVIEW THIS DIFF. Every line is a promise to an external consumer."
  exit 0
fi

if [ ! -f "$ALLOW" ]; then
  echo "G0.9: no allowlist at $ALLOW -- run with --record, then REVIEW it"
  exit 1
fi

actual=$(mktemp)
surface > "$actual"

added=$(comm -13 "$ALLOW" "$actual")
removed=$(comm -23 "$ALLOW" "$actual")

echo "G0.9 public surface -- $SRC"
echo

if [ -n "$added" ]; then
  echo "  FAIL  items NOT in the reviewed allowlist:"
  echo "$added" | sed 's/^/          + /'
  echo
fi
if [ -n "$removed" ]; then
  echo "  NOTE  allowlisted items no longer present (narrowing -- confirm intent):"
  echo "$removed" | sed 's/^/          - /'
  echo
fi

n_allow=$(wc -l < "$ALLOW" | tr -d ' ')
n_added=$(if [ -n "$added" ]; then echo "$added" | wc -l | tr -d ' '; else echo 0; fi)
rm -f "$actual"

if [ "$n_added" -gt 0 ]; then
  printf 'G0.9: FAILED -- %s unapproved public item(s), %s allowlisted\n' "$n_added" "$n_allow"
  echo
  echo "An addition here is a new promise to every external consumer, made"
  echo "without review. If it is intended, run --record and review the diff."
  exit 1
fi

printf 'G0.9: PASS -- public surface matches the reviewed allowlist (%s items)\n' "$n_allow"
