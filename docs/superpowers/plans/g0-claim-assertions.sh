#!/bin/bash
# G0.7 — CLAIM ASSERTIONS.
#
# G0.3/G0.4/G0.5 prove the code compiles, tests, and lints. They cannot prove a
# NEGATIVE claim: code that never had a feature compiles fine, so "deleted",
# "narrowed to pub(crate)", and "made private" are unfalsifiable by a build.
#
# Revision 8 shipped seven such claims false, five findable by grep in under a
# minute (SEC-32, SEC-33, RA-16, RA-17, RA-23a). Rust Architect and Chief
# Security Officer proposed this gate independently, and neither proposed a new
# architectural rule -- the Evidence Rule is the one row the freeze document
# marks "human discipline, no mechanical backstop", and this is that backstop.
#
# TRACEABILITY IS BIDIRECTIONAL.
#   Every assertion carries a stable id (A01, A02, ...) and names the finding it
#   guards. Every finding in the plan cites the assertion id that fails if it
#   regresses. Neither direction may be blank:
#     - an assertion with no finding is a check nobody asked for
#     - a finding with no assertion is a claim nothing enforces
#   The registry table in the plan is the index; `--list` prints this side of it.
#   Ids are stable and never reused: retiring an assertion leaves a gap.
#
# Usage:
#   bash docs/superpowers/plans/g0-claim-assertions.sh [crate-src-dir]
#   bash docs/superpowers/plans/g0-claim-assertions.sh --list
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LIST=0
if [ "${1:-}" = "--list" ]; then LIST=1; shift; fi
SRC="${1:-$HERE/../../../rust/airo_mind/src}"
PASS=0
FAIL=0

# PRECONDITION. Without this, every `absent` assertion passes trivially against
# a missing tree: `grep` finds nothing in a directory that is not there. Run
# against /nonexistent this script reported "18 passed, 5 FAILED (of 23)" --
# mostly green, measuring no code at all. A gate that cannot tell "the defect is
# absent" from "the source is absent" is not evidence; it is the strongest form
# of the vacuity it was built to prevent.
if [ ! -d "$SRC" ]; then
  echo "G0.7: ABORT -- source tree not found: $SRC" >&2
  exit 2
fi
n_rs=$(find "$SRC" -name '*.rs' | wc -l | tr -d ' ')
if [ "$n_rs" -lt 10 ]; then
  echo "G0.7: ABORT -- only $n_rs .rs files under $SRC; expected the full crate" >&2
  exit 2
fi

# assert KIND ID FINDING GLOB PATTERN DESC
assert() {
  local kind="$1" id="$2" finding="$3" glob="$4" pat="$5" desc="$6" hits
  if [ "$LIST" -eq 1 ]; then
    printf '%-4s %-8s %-6s %-12s %s\n' "$id" "$finding" "$kind" "$glob" "$desc"
    return
  fi
  hits=$(grep -rn --include="$glob" -e "$pat" "$SRC" 2>/dev/null)
  if [ "$kind" = absent ]; then
    if [ -z "$hits" ]; then
      printf '  PASS  %-4s %-8s %s\n' "$id" "$finding" "$desc"
      PASS=$((PASS + 1))
    else
      printf '  FAIL  %-4s %-8s %s\n' "$id" "$finding" "$desc"
      printf '        claimed ABSENT, found:\n'
      echo "$hits" | sed "s|$SRC|src|" | sed 's/^/          /'
      FAIL=$((FAIL + 1))
    fi
  else
    if [ -n "$hits" ]; then
      printf '  PASS  %-4s %-8s %s\n' "$id" "$finding" "$desc"
      PASS=$((PASS + 1))
    else
      printf '  FAIL  %-4s %-8s %s  (claimed PRESENT, absent)\n' "$id" "$finding" "$desc"
      FAIL=$((FAIL + 1))
    fi
  fi
}

if [ "$LIST" -eq 1 ]; then
  echo "G0.7 assertion registry"
  printf '%-4s %-8s %-6s %-12s %s\n' ID FINDING KIND FILE CLAIM
else
  echo "G0.7 claim assertions -- $SRC"
fi
echo

assert absent  A01 SEC-33  'seed.rs'      'pub fn as_bytes(&self) -> &\[u8; 64\]' 'Seed::as_bytes deleted (64-byte master seed)'
assert absent  A02 RA-17   'identity.rs'  'pub fn sign(&self, msg: &\[u8\])'      'RootIdentity::sign not pub (signing oracle)'
assert absent  A03 RA-17b  'device.rs'    'pub fn sign(&self, msg: &\[u8\])'      'DeviceKey::sign deleted (zero callers)'
assert present A04 SEC-32  'identifier.rs' 'pub struct ContextId'                 'canonical identifier type exists (I6: a boundary, not a call)'
assert absent  A04b SEC-32 'aggregate.rs' 'pub fn [a-z_]*(&mut self, context_id: &str\|pub fn [a-z_]*(&self, context_id: &str' 'no raw identifier crosses the PUBLIC Vault boundary'
assert absent  A05 RA-23a  'package.rs'   '^    pub revocation_epoch'             'RecoveryPackage::revocation_epoch private'
assert absent  A06 RA-23a  'package.rs'   '^    pub identity_public_key'          'RecoveryPackage::identity_public_key private'
assert absent  A07 RA-23a  'device.rs'    '^    pub device_id'                    'DeviceCertificate::device_id private'
assert absent  A08 RA-23a  'device.rs'    '^    pub signature'                    'DeviceCertificate::signature private'
assert present A09 RA-23a  'package.rs'   'with_.*_tampered'                      'cfg(test) tamper constructors exist'
assert absent  A10 RA-24   '*.rs'         '^[^/]*format!("{b:02x}")'              'no per-byte format! in CODE (350.82ms vs 16.55ms)'
assert absent  A11 RA-19   '*.rs'         'len() as u32'                          'no unchecked length cast on a signing payload'
assert absent  A12 SEC-46  'package.rs'   '\*index += 1'                          'no unchecked increment on the nonce path'
assert absent  A13 RA-3    'seed.rs'      'OsRng'                                 'seed.rs does not call OsRng'
assert absent  A14 RA-3    'device.rs'    'OsRng'                                 'device.rs does not call OsRng'
assert absent  A15 RA-3    'package.rs'   'OsRng'                                 'package.rs does not call OsRng'
assert absent  A16 SEC-38  'aggregate.rs' 'filter(|c| c.verify_against'           'restore admits via admit_device, not an inline filter'
assert present A17 SEC-35  'package.rs'   'push_len_prefixed(&mut aad, &self.nonce)' 'the package nonce is authenticated'
assert present A18 SEC-36  'package.rs'   'set_head_epoch'                        'head_epoch is carried in the sealed trailer, not re-derived'
assert absent  A19 RA-25   '*.rs'         'consumed by link_content'              'no stale allow(dead_code) on content_id'
assert absent  A20 SEC-37  'package.rs'   'pub(super) fn as_bytes'                'KeyBytes::as_bytes is package-scoped, not crate-wide'
assert present A21 SEC-40  'restore.rs'   'source.ledger.validate()'              'a caller-supplied ledger is validated'
assert absent  A22 SEC-32  'seed.rs'      'pub fn as_bytes(&self) -> &\[u8; 32\]' 'no 32-byte seed accessor either'

if [ "$LIST" -eq 1 ]; then exit 0; fi

echo
printf 'G0.7: %d passed, %d FAILED  (of %d assertions)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
if [ "$FAIL" -gt 0 ]; then
  echo
  echo "A FAIL means the plan records a change its own code does not contain."
  echo "Making that impossible to report as done is the purpose of this gate."
fi
[ "$FAIL" -eq 0 ]
