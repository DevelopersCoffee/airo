#!/bin/bash
# G0.8 — EXTERNAL-CONSUMER PROBE.
#
# Every architectural claim about the façade is a claim about the crate seen
# from OUTSIDE. Nothing in-tree looks from outside: `#[cfg(test)] mod tests` is
# inside the crate, so `pub(crate)` and `pub` are indistinguishable to it. Three
# Revision 8 findings were reachable only this way, and one of them — the
# 64-byte master seed being `pub` — is the most total secret in the system.
#
# Two probe kinds:
#
#   DENY  — a statement that MUST NOT compile. If it compiles, the façade is
#           open and the claim is false. This is the important one: it is the
#           only mechanical check for "unreachable from outside".
#   ALLOW — a statement that MUST compile. Catches the opposite failure, where
#           the façade is so tight a supported journey is unreachable. Revision
#           7 shipped no callable restore path and compiled cleanly (RA-18);
#           Revision 8 shipped an unnameable `DeviceCertificate` behind a `pub`
#           `trust_device`, and a non-blind restore reachable only in tests
#           (SEC-39).
#
# Usage: bash docs/superpowers/plans/g0-consumer-probe.sh [crate-dir]
set -u
SP=/private/tmp/claude-501/-Users-udaychauhan-workspace-airo/e1fc7091-9136-4c43-b3e5-8187b71864a4/scratchpad
CRATE="${1:-$SP/rev7}"
WORK="$SP/g08probe"
PASS=0
FAIL=0

rm -rf "$WORK"
mkdir -p "$WORK/src"
cat > "$WORK/Cargo.toml" <<TOML
[package]
name = "consumer_probe"
version = "0.0.0"
edition = "2021"

[dependencies]
airo_mind = { path = "$CRATE" }
serde_json = "1"

[workspace]
TOML

MNEMONIC='"abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"'

probe() {
  local kind="$1" id="$2" desc="$3" body="$4"
  cat > "$WORK/src/main.rs" <<RS
#![allow(unused, clippy::all)]
use airo_mind::*;
fn main() {
    let seed = seed_from_mnemonic($MNEMONIC).unwrap();
    let identity = RootIdentity::from_seed(&seed).unwrap();
    let mut vault = Vault::new(identity.public_key());
    $body
}
RS
  local out
  out=$(cd "$WORK" && cargo build --quiet 2>&1)
  local built=$?
  if [ "$kind" = DENY ]; then
    if [ $built -ne 0 ]; then
      printf '  PASS  DENY   %-8s %s\n' "$id" "$desc"
      PASS=$((PASS + 1))
    else
      printf '  FAIL  DENY   %-8s %s\n' "$id" "$desc"
      printf '        COMPILED from outside the crate; the façade is open\n'
      FAIL=$((FAIL + 1))
    fi
  else
    if [ $built -eq 0 ]; then
      printf '  PASS  ALLOW  %-8s %s\n' "$id" "$desc"
      PASS=$((PASS + 1))
    else
      printf '  FAIL  ALLOW  %-8s %s\n' "$id" "$desc"
      printf '        does NOT compile; a supported journey is unreachable\n'
      echo "$out" | grep -m2 '^error' | sed 's/^/          /'
      FAIL=$((FAIL + 1))
    fi
  fi
}

echo "G0.8 external-consumer probe -- against $CRATE"
echo

echo "Key material and signing must be unreachable:"
probe DENY SEC-33 'the 64-byte master seed is not readable' \
  'let b = seed.as_bytes(); println!("{}", b[0]);'
probe DENY RA-17 'the root identity is not a signing oracle' \
  'let s = identity.sign(b"attacker chosen"); println!("{}", s[0]);'
probe DENY RA-17b 'device keys cannot be minted or used to sign' \
  'let k = DeviceKey::generate().unwrap(); println!("{:?}", k.sign(b"x")[0]);'

echo
echo "AAD-covered header fields must not be publicly mutable:"
probe DENY RA-23a 'a package header cannot be rewritten by a consumer' \
  'let mut p = RecoveryPackage::export(&vault, &seed).unwrap();
   p.revocation_epoch = 9999; println!("{}", p.revocation_epoch);'

echo
echo "The Vault must be the only door to an envelope:"
probe DENY SEC-43 'an envelope cannot be deserialized outside the Vault' \
  'let e: ContentEnvelope = serde_json::from_slice(br#"{"content_id":"forged","wrappings":[]}"#).unwrap();
   println!("{:?}", e);'

echo
echo "Supported journeys must be reachable:"
probe ALLOW RA-18 'the full restore path is callable' \
  'let (_k, _e) = vault.add_content("n", &["inbox"]).unwrap();
   let p = RecoveryPackage::export(&vault, &seed).unwrap();
   let v = SealedRestore::load(&p, &seed).unwrap()
       .apply_revocations(&RevocationSource::package_only()).into_vault();
   println!("{}", v.is_content_destroyed("n"));'
probe ALLOW SEC-39 'a NON-blind restore is constructible' \
  'let p = RecoveryPackage::export(&vault, &seed).unwrap();
   let src = RevocationSource::replayed_from_log(Default::default(), Default::default());
   let a = SealedRestore::load(&p, &seed).unwrap().apply_revocations(&src);
   assert!(!a.was_blind());'
probe ALLOW SEC-38 'the device-trust journey is callable' \
  'let cert: DeviceCertificate = unimplemented!();
   vault.trust_device(cert).unwrap(); println!("{}", vault.trusted_devices().len());'
probe ALLOW RA-Q4 'content can actually be sealed and opened' \
  'let (k, e) = vault.add_content("n", &["inbox"]).unwrap();
   let c = k.seal(b"plaintext").unwrap();
   assert_eq!(k.open(&c).unwrap().as_slice(), b"plaintext");
   let s = vault.seal_envelope(&e).unwrap();
   let _ = vault.open_envelope(&s).unwrap();'

echo
printf 'G0.8: %d passed, %d FAILED\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo
  echo "A failed DENY means a claimed-private item is publicly reachable."
  echo "A failed ALLOW means the façade hides a journey the product needs."
  echo "Revision 8 shipped both kinds at once."
fi
[ "$FAIL" -eq 0 ]
