//! SHA-256, for verifying model files against digests pinned in source.
//!
//! # Why this is written out rather than pulled in
//!
//! `sha2` would be one line. It would also be a Constitution §6 dependency
//! scorecard — licence, maintenance, security, binary impact, bus factor — for
//! ninety lines of a fully specified algorithm with published test vectors.
//! The vectors are the check that this is correct, and they are cheaper to
//! review than a supply chain.
//!
//! Not constant-time and not intended to be: this compares an asset's digest to
//! a value compiled into the binary, not a secret to an attacker-supplied one.
//! `C5` forbids capabilities from carrying encryption primitives or key
//! material, and a hash over a public file is neither.

const K: [u32; 64] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

const INITIAL: [u32; 8] = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
];

/// Streaming SHA-256.
///
/// Streaming rather than one-shot because a generation model is half a
/// gigabyte, and reading it into memory to hash it would undo the point of
/// `I7`.
pub struct Sha256 {
    state: [u32; 8],
    buffer: [u8; 64],
    buffered: usize,
    total_bits: u64,
}

impl Default for Sha256 {
    fn default() -> Self {
        Self::new()
    }
}

impl Sha256 {
    pub fn new() -> Self {
        Self {
            state: INITIAL,
            buffer: [0; 64],
            buffered: 0,
            total_bits: 0,
        }
    }

    pub fn update(&mut self, mut data: &[u8]) {
        self.total_bits = self.total_bits.wrapping_add((data.len() as u64) * 8);

        if self.buffered > 0 {
            let need = 64 - self.buffered;
            let take = need.min(data.len());
            self.buffer[self.buffered..self.buffered + take].copy_from_slice(&data[..take]);
            self.buffered += take;
            data = &data[take..];
            // Still partial. `data` is necessarily empty here, and falling
            // through would run the tail copy below and reset `buffered` to
            // zero -- silently dropping everything buffered so far. Caught by
            // `chunking_does_not_change_the_result`.
            if self.buffered < 64 {
                return;
            }
            let block = self.buffer;
            self.compress(&block);
            self.buffered = 0;
        }

        // Clippy 1.98 prefers `as_chunks::<64>()`; that API is still
        // unstable on the 1.83 toolchain some host checks use.
        #[allow(clippy::chunks_exact_to_as_chunks)]
        let mut chunks = data.chunks_exact(64);
        for chunk in &mut chunks {
            let mut block = [0u8; 64];
            block.copy_from_slice(chunk);
            self.compress(&block);
        }

        let rest = chunks.remainder();
        self.buffer[..rest.len()].copy_from_slice(rest);
        self.buffered = rest.len();
    }

    /// Lowercase hex, which is the form digests are pinned in.
    pub fn finish(mut self) -> String {
        let bits = self.total_bits;

        self.update_raw(&[0x80]);
        while self.buffered != 56 {
            self.update_raw(&[0x00]);
        }
        self.update_raw(&bits.to_be_bytes());

        let mut out = String::with_capacity(64);
        for word in self.state {
            out.push_str(&format!("{word:08x}"));
        }
        out
    }

    /// Padding bytes must not count towards the length that padding encodes.
    fn update_raw(&mut self, data: &[u8]) {
        for &byte in data {
            self.buffer[self.buffered] = byte;
            self.buffered += 1;
            if self.buffered == 64 {
                let block = self.buffer;
                self.compress(&block);
                self.buffered = 0;
            }
        }
    }

    fn compress(&mut self, block: &[u8; 64]) {
        let mut w = [0u32; 64];
        for (i, word) in w.iter_mut().take(16).enumerate() {
            *word = u32::from_be_bytes([
                block[i * 4],
                block[i * 4 + 1],
                block[i * 4 + 2],
                block[i * 4 + 3],
            ]);
        }
        for i in 16..64 {
            let s0 = w[i - 15].rotate_right(7) ^ w[i - 15].rotate_right(18) ^ (w[i - 15] >> 3);
            let s1 = w[i - 2].rotate_right(17) ^ w[i - 2].rotate_right(19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16]
                .wrapping_add(s0)
                .wrapping_add(w[i - 7])
                .wrapping_add(s1);
        }

        let [mut a, mut b, mut c, mut d, mut e, mut f, mut g, mut h] = self.state;

        for i in 0..64 {
            let s1 = e.rotate_right(6) ^ e.rotate_right(11) ^ e.rotate_right(25);
            let ch = (e & f) ^ ((!e) & g);
            let t1 = h
                .wrapping_add(s1)
                .wrapping_add(ch)
                .wrapping_add(K[i])
                .wrapping_add(w[i]);
            let s0 = a.rotate_right(2) ^ a.rotate_right(13) ^ a.rotate_right(22);
            let maj = (a & b) ^ (a & c) ^ (b & c);
            let t2 = s0.wrapping_add(maj);

            h = g;
            g = f;
            f = e;
            e = d.wrapping_add(t1);
            d = c;
            c = b;
            b = a;
            a = t1.wrapping_add(t2);
        }

        for (slot, value) in self.state.iter_mut().zip([a, b, c, d, e, f, g, h]) {
            *slot = slot.wrapping_add(value);
        }
    }
}

/// Hashes a file without reading it into memory.
pub fn file_digest(path: &std::path::Path) -> std::io::Result<String> {
    use std::io::Read;

    let mut file = std::fs::File::open(path)?;
    let mut hasher = Sha256::new();
    // 1 MiB: large enough that syscall overhead disappears, small enough that
    // hashing a 500 MB model does not show up as a memory spike.
    let mut buffer = vec![0u8; 1 << 20];
    loop {
        let read = file.read(&mut buffer)?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
    }
    Ok(hasher.finish())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn digest(input: &[u8]) -> String {
        let mut h = Sha256::new();
        h.update(input);
        h.finish()
    }

    /// The published NIST vectors. These are the reason this file is allowed to
    /// exist instead of a dependency.
    #[test]
    fn matches_the_published_vectors() {
        assert_eq!(
            digest(b""),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        );
        assert_eq!(
            digest(b"abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
        assert_eq!(
            digest(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        );
    }

    /// A million 'a's: crosses many block boundaries and exercises the length
    /// counter, which is where a hand-written implementation goes wrong.
    #[test]
    fn matches_the_long_vector() {
        let mut h = Sha256::new();
        for _ in 0..1000 {
            h.update(&[b'a'; 1000]);
        }
        assert_eq!(
            h.finish(),
            "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0"
        );
    }

    /// Streaming in awkward pieces must equal hashing in one go — the property
    /// that makes `file_digest`'s chunking safe.
    #[test]
    fn chunking_does_not_change_the_result() {
        let data: Vec<u8> = (0..5000u32).map(|i| (i % 251) as u8).collect();
        let whole = digest(&data);

        for chunk in [1usize, 7, 63, 64, 65, 1000] {
            let mut h = Sha256::new();
            for piece in data.chunks(chunk) {
                h.update(piece);
            }
            assert_eq!(h.finish(), whole, "chunk size {chunk} changed the digest");
        }
    }

    /// Exactly 55, 56 and 64 bytes: the lengths where padding either just fits,
    /// forces a second block, or fills a block exactly.
    #[test]
    fn the_padding_boundaries_are_right() {
        assert_eq!(
            digest(&[b'a'; 55]),
            "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318"
        );
        assert_eq!(
            digest(&[b'a'; 56]),
            "b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a"
        );
        assert_eq!(
            digest(&[b'a'; 64]),
            "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb"
        );
    }

    #[test]
    fn hashes_a_file_off_disk() {
        let path = std::env::temp_dir().join(format!("airo_digest_{}.bin", std::process::id()));
        std::fs::write(&path, b"abc").unwrap();
        assert_eq!(
            file_digest(&path).unwrap(),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
        let _ = std::fs::remove_file(&path);
    }
}
