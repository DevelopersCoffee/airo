//! Incremental 16 kHz mono PCM WAV writer.
//!
//! Header sizes are rewritten after every sample write so a process kill
//! still leaves a file [`crate::preprocess_path`] can decode. `wav::decode`
//! already accepts a truncated final chunk; stale *zero* sizes would look
//! like silence, so this writer never leaves `data` size at 0 once audio
//! has been accepted.

use std::fs::{File, OpenOptions};
use std::io::{Seek, SeekFrom, Write};
use std::path::Path;

use crate::TARGET_CHANNELS;
use crate::TARGET_SAMPLE_RATE;

/// Append-only 16-bit PCM WAVE file with crash-durable size fields.
pub struct IncrementalWavWriter {
    file: File,
    data_bytes: u32,
}

impl IncrementalWavWriter {
    /// Creates or truncates [path] and writes a valid empty WAVE header.
    pub fn create(path: impl AsRef<Path>) -> Result<Self, String> {
        let path = path.as_ref();
        if let Some(dir) = path.parent() {
            std::fs::create_dir_all(dir).map_err(|e| format!("creating {}: {e}", dir.display()))?;
        }
        let mut file = OpenOptions::new()
            .create(true)
            .write(true)
            .truncate(true)
            .open(path)
            .map_err(|e| format!("opening {}: {e}", path.display()))?;
        file.write_all(&wav_header(0))
            .map_err(|e| format!("writing WAVE header: {e}"))?;
        file.flush()
            .map_err(|e| format!("flushing WAVE header: {e}"))?;
        Ok(Self {
            file,
            data_bytes: 0,
        })
    }

    /// Appends samples and updates RIFF/`data` sizes before returning.
    pub fn write_samples(&mut self, samples: &[i16]) -> Result<(), String> {
        if samples.is_empty() {
            return Ok(());
        }
        for sample in samples {
            self.file
                .write_all(&sample.to_le_bytes())
                .map_err(|e| format!("writing PCM: {e}"))?;
        }
        let added = (samples.len() * 2) as u32;
        self.data_bytes = self.data_bytes.saturating_add(added);
        self.sync_sizes()?;
        self.file
            .seek(SeekFrom::End(0))
            .map_err(|e| format!("seeking WAVE end: {e}"))?;
        Ok(())
    }

    pub fn data_bytes(&self) -> u32 {
        self.data_bytes
    }

    pub fn sample_count(&self) -> u64 {
        u64::from(self.data_bytes) / 2
    }

    fn sync_sizes(&mut self) -> Result<(), String> {
        let riff_size = 36u32.saturating_add(self.data_bytes);
        self.file
            .seek(SeekFrom::Start(4))
            .map_err(|e| format!("seeking RIFF size: {e}"))?;
        self.file
            .write_all(&riff_size.to_le_bytes())
            .map_err(|e| format!("writing RIFF size: {e}"))?;
        self.file
            .seek(SeekFrom::Start(40))
            .map_err(|e| format!("seeking data size: {e}"))?;
        self.file
            .write_all(&self.data_bytes.to_le_bytes())
            .map_err(|e| format!("writing data size: {e}"))?;
        self.file
            .flush()
            .map_err(|e| format!("flushing WAVE sizes: {e}"))?;
        Ok(())
    }
}

impl Drop for IncrementalWavWriter {
    fn drop(&mut self) {
        let _ = self.sync_sizes();
    }
}

fn wav_header(data_bytes: u32) -> [u8; 44] {
    let mut header = [0u8; 44];
    header[0..4].copy_from_slice(b"RIFF");
    header[4..8].copy_from_slice(&(36u32 + data_bytes).to_le_bytes());
    header[8..12].copy_from_slice(b"WAVE");
    header[12..16].copy_from_slice(b"fmt ");
    header[16..20].copy_from_slice(&16u32.to_le_bytes());
    header[20..22].copy_from_slice(&1u16.to_le_bytes());
    header[22..24].copy_from_slice(&TARGET_CHANNELS.to_le_bytes());
    header[24..28].copy_from_slice(&TARGET_SAMPLE_RATE.to_le_bytes());
    let byte_rate = TARGET_SAMPLE_RATE * u32::from(TARGET_CHANNELS) * 2;
    header[28..32].copy_from_slice(&byte_rate.to_le_bytes());
    header[32..34].copy_from_slice(&(TARGET_CHANNELS * 2).to_le_bytes());
    header[34..36].copy_from_slice(&16u16.to_le_bytes());
    header[36..40].copy_from_slice(b"data");
    header[40..44].copy_from_slice(&data_bytes.to_le_bytes());
    header
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::preprocess_path;

    #[test]
    fn empty_file_is_a_valid_wav() {
        let dir = std::env::temp_dir().join(format!("airo-wav-empty-{}", std::process::id()));
        let path = dir.join("empty.wav");
        let writer = IncrementalWavWriter::create(&path).unwrap();
        drop(writer);
        let pcm = preprocess_path(&path).unwrap();
        assert!(pcm.samples.is_empty());
        assert_eq!(pcm.sample_rate_hz, TARGET_SAMPLE_RATE);
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn samples_round_trip_through_preprocess() {
        let dir = std::env::temp_dir().join(format!("airo-wav-rt-{}", std::process::id()));
        let path = dir.join("speech.wav");
        let mut writer = IncrementalWavWriter::create(&path).unwrap();
        writer.write_samples(&[1, -2, 3, -4]).unwrap();
        drop(writer);
        let pcm = preprocess_path(&path).unwrap();
        assert_eq!(pcm.samples, vec![1, -2, 3, -4]);
        let _ = std::fs::remove_dir_all(dir);
    }
}
