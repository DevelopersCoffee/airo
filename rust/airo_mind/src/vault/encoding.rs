//! Serde helpers for fixed-size byte arrays, and length-prefixing.
//!
//! serde 1 has no array impl above 32 bytes and no feature that adds one.
//! Hand-written rather than pulling `serde_bytes` or `serde-big-array`: a new
//! crate on the crypto path needs a governance scorecard (Constitution §6),
//! and this is twenty lines.
//!
//! Encoding, by field class. Two encodings, and the split is measured, not
//! aesthetic (`ADR-0017`):
//!
//! - **Fixed-size key and signature fields** — lowercase hex, so the package
//!   stays inspectable in a text editor, which matters for a file users are
//!   told to store themselves.
//! - **The outer `ciphertext` / `nonce` / `kdf_salt`** — base64. The package
//!   double-encodes: a JSON payload, then that ciphertext text-encoded again
//!   in the envelope. Hex on the outer blob costs a hard 2.0×, putting `V4`'s
//!   `≤ 3× compact` floor at 3.30× — unmeetable at any inner encoding. Base64
//!   costs 1.33× and clears every measured shape. The blob is opaque either
//!   way, so nothing inspectable is lost.
//!
//! **Never `format!("{b:02x}")` per byte.** That allocates one `String` per
//! byte; on a 100k-context vault it measures 350.82 ms against 16.55 ms for
//! the pre-sized form below — a 21× difference, and a **4.0× regression**
//! against the JSON decimal arrays it replaces. `PERF` found this on the
//! Revision 8 rollout, and Revision 7 already shipped the slow pattern on the
//! `DeviceCertificate` path.

use super::error::VaultError;

/// Length-prefixes with a **checked** cast.
///
/// `as u32` truncates silently above `u32::MAX`, and a truncated length breaks
/// injectivity — two different inputs producing identical AAD bytes. Lives
/// here, not in `envelope.rs`, so `package.rs` stops importing its wire-format
/// helper from the content-wrapping module (`RA-4`).
pub(crate) fn push_len_prefixed(out: &mut Vec<u8>, bytes: &[u8]) -> Result<(), VaultError> {
    let len = u32::try_from(bytes.len()).map_err(|_| VaultError::ValueTooLong)?;
    out.extend_from_slice(&len.to_be_bytes());
    out.extend_from_slice(bytes);
    Ok(())
}

/// Lowercase hex into a single pre-sized allocation.
///
/// One `String` for the whole field, not one per byte.
pub(crate) fn hex_of(bytes: &[u8]) -> String {
    hex_into(bytes)
}

fn hex_into(bytes: &[u8]) -> String {
    const DIGITS: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        out.push(DIGITS[(b >> 4) as usize] as char);
        out.push(DIGITS[(b & 0x0f) as usize] as char);
    }
    out
}

/// Decodes hex over **bytes**, never over `&str`.
///
/// `RA-20`: the previous form checked `text.len() != 64` — a *byte* count —
/// and then sliced `&text[i * 2..i * 2 + 2]`. A multi-byte character that
/// straddles an even offset lands off a char boundary and `&str` slicing
/// panics:
///
/// ```text
/// input:  "a" * 61 + "é" + "a"      // 64 bytes, 63 chars
/// panic:  end byte index 62 is not a char boundary; it is inside 'é'
/// ```
///
/// Reachable pre-auth once `C3` sync parses device certificates, in a crate
/// carrying `#![forbid(unsafe_code)]`. Operating on `as_bytes()` makes the
/// panic structurally impossible rather than length-checked. Note the bug
/// needs the character to straddle an *even* offset, which is why a
/// hand-written negative test plausibly misses it and the fuzz target below
/// does not.
fn hex_from(text: &str, out: &mut [u8]) -> Result<(), &'static str> {
    let b = text.as_bytes();
    if b.len() != out.len() * 2 {
        return Err("wrong hex length");
    }
    fn nibble(c: u8) -> Result<u8, &'static str> {
        match c {
            b'0'..=b'9' => Ok(c - b'0'),
            b'a'..=b'f' => Ok(c - b'a' + 10),
            _ => Err("invalid hex"),
        }
    }
    for (i, slot) in out.iter_mut().enumerate() {
        *slot = (nibble(b[i * 2])? << 4) | nibble(b[i * 2 + 1])?;
    }
    Ok(())
}

pub(crate) mod hex_array_32 {
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S: Serializer>(bytes: &[u8; 32], s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&super::hex_into(bytes))
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<[u8; 32], D::Error> {
        use serde::de::Error;
        let text = String::deserialize(d)?;
        let mut out = [0u8; 32];
        super::hex_from(&text, &mut out).map_err(D::Error::custom)?;
        Ok(out)
    }
}

pub(crate) mod hex_array_64 {
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S: Serializer>(bytes: &[u8; 64], s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&super::hex_into(bytes))
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<[u8; 64], D::Error> {
        use serde::de::Error;
        let text = String::deserialize(d)?;
        let mut out = [0u8; 64];
        super::hex_from(&text, &mut out).map_err(D::Error::custom)?;
        Ok(out)
    }
}

/// Base64 for the outer opaque blobs. `ADR-0017`, budget `V4`.
///
/// Hand-written for the same reason as the hex helpers: a new crate on the
/// crypto path needs a governance scorecard (Constitution §6), and this is
/// standard alphabet, padded, ~30 lines. It must round-trip exactly; the
/// property test below is not optional.
pub(crate) mod base64_bytes {
    use serde::{Deserialize, Deserializer, Serializer};

    const ALPHABET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    pub(crate) fn encode(bytes: &[u8]) -> String {
        let mut out = String::with_capacity(bytes.len().div_ceil(3) * 4);
        for chunk in bytes.chunks(3) {
            let b = [
                chunk[0],
                *chunk.get(1).unwrap_or(&0),
                *chunk.get(2).unwrap_or(&0),
            ];
            let n = (u32::from(b[0]) << 16) | (u32::from(b[1]) << 8) | u32::from(b[2]);
            out.push(ALPHABET[(n >> 18) as usize & 63] as char);
            out.push(ALPHABET[(n >> 12) as usize & 63] as char);
            out.push(if chunk.len() > 1 {
                ALPHABET[(n >> 6) as usize & 63] as char
            } else {
                '='
            });
            out.push(if chunk.len() > 2 {
                ALPHABET[n as usize & 63] as char
            } else {
                '='
            });
        }
        out
    }

    pub(crate) fn decode(text: &str) -> Result<Vec<u8>, &'static str> {
        let b = text.as_bytes();
        if !b.len().is_multiple_of(4) {
            return Err("base64 length not a multiple of 4");
        }
        fn val(c: u8) -> Result<u32, &'static str> {
            match c {
                b'A'..=b'Z' => Ok(u32::from(c - b'A')),
                b'a'..=b'z' => Ok(u32::from(c - b'a') + 26),
                b'0'..=b'9' => Ok(u32::from(c - b'0') + 52),
                b'+' => Ok(62),
                b'/' => Ok(63),
                _ => Err("invalid base64"),
            }
        }
        let mut out = Vec::with_capacity(b.len() / 4 * 3);
        for chunk in b.chunks(4) {
            let pad = chunk.iter().filter(|c| **c == b'=').count();
            if pad > 2 || (pad > 0 && !std::ptr::eq(chunk, &b[b.len() - 4..])) {
                return Err("misplaced base64 padding");
            }
            let n = (val(chunk[0])? << 18)
                | (val(chunk[1])? << 12)
                | (if pad < 2 { val(chunk[2])? } else { 0 } << 6)
                | (if pad < 1 { val(chunk[3])? } else { 0 });
            out.push((n >> 16) as u8);
            if pad < 2 {
                out.push((n >> 8) as u8);
            }
            if pad < 1 {
                out.push(n as u8);
            }
        }
        Ok(out)
    }

    pub fn serialize<S: Serializer>(bytes: &[u8], s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&encode(bytes))
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<Vec<u8>, D::Error> {
        use serde::de::Error;
        let text = String::deserialize(d)?;
        decode(&text).map_err(D::Error::custom)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hex_rejects_multibyte_at_an_even_offset_instead_of_panicking() {
        // RA-20: 64 bytes, 63 chars, 'é' straddling offset 61..63.
        let hostile = "a".repeat(61) + "é" + "a";
        assert_eq!(hostile.len(), 64);
        let mut out = [0u8; 32];
        assert!(hex_from(&hostile, &mut out).is_err());
    }

    #[test]
    fn base64_round_trips_every_length_class() {
        for n in 0..=64 {
            let bytes: Vec<u8> = (0..n).map(|i| (i * 7 + 3) as u8).collect();
            let text = base64_bytes::encode(&bytes);
            assert_eq!(base64_bytes::decode(&text).unwrap(), bytes, "n = {n}");
        }
    }

    #[test]
    fn base64_rejects_misplaced_padding() {
        assert!(base64_bytes::decode("A=BC").is_err());
        assert!(base64_bytes::decode("AB=C").is_err());
        assert!(base64_bytes::decode("ABC").is_err());
    }
}
