//! One capture stream → durable file + optional live consumer.
//!
//! Live processing is a bounded, drop-newest (when the channel is full)
//! consumer of the same samples the file writer just accepted. Ingest never
//! waits on inference. A dead live consumer does not stop the file.

use std::path::{Path, PathBuf};
use std::sync::mpsc::{self, Receiver, SyncSender, TrySendError};

use crate::wav_write::IncrementalWavWriter;

/// Outcome of one [`CaptureFanout::ingest`].
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct FanoutReport {
    pub file_samples: u64,
    pub live_accepted: bool,
    pub live_dropped: bool,
}

/// Authoritative capture fan-out: file is durability, live is optional.
pub struct CaptureFanout {
    path: PathBuf,
    wav: IncrementalWavWriter,
    live: Option<SyncSender<Vec<i16>>>,
}

impl CaptureFanout {
    /// Opens the WAV at [path]. Live consumer is attached with [`Self::with_live`].
    pub fn create_file(path: impl AsRef<Path>) -> Result<Self, String> {
        let path = path.as_ref().to_path_buf();
        let wav = IncrementalWavWriter::create(&path)?;
        Ok(Self {
            path,
            wav,
            live: None,
        })
    }

    /// Bounded live consumer. Capacity is in *chunks*, not samples — keep it
    /// small so a stuck STT worker cannot retain unbounded PCM.
    pub fn with_bounded_live(self, chunk_capacity: usize) -> (Self, Receiver<Vec<i16>>) {
        let (tx, rx) = mpsc::sync_channel(chunk_capacity.max(1));
        (self.with_live(tx), rx)
    }

    pub fn with_live(mut self, tx: SyncSender<Vec<i16>>) -> Self {
        self.live = Some(tx);
        self
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    /// Writes samples to the file first, then non-blocking-sends to live.
    ///
    /// A full or disconnected live channel is reported, never a `Err` — the
    /// file is the recovery artifact.
    pub fn ingest(&mut self, samples: &[i16]) -> Result<FanoutReport, String> {
        self.wav.write_samples(samples)?;
        let mut live_accepted = false;
        let mut live_dropped = false;
        if let Some(tx) = &self.live {
            match tx.try_send(samples.to_vec()) {
                Ok(()) => live_accepted = true,
                Err(TrySendError::Full(_)) | Err(TrySendError::Disconnected(_)) => {
                    live_dropped = true;
                }
            }
        }
        Ok(FanoutReport {
            file_samples: self.wav.sample_count(),
            live_accepted,
            live_dropped,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::preprocess_path;

    fn temp_wav(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("airo-fanout-{}-{}", name, std::process::id()));
        dir.join("capture.wav")
    }

    fn cleanup(path: &Path) {
        if let Some(dir) = path.parent() {
            let _ = std::fs::remove_dir_all(dir);
        }
    }

    #[test]
    fn ingest_writes_file_even_when_live_is_disconnected() {
        let path = temp_wav("dead-live");
        let (tx, rx) = mpsc::sync_channel(1);
        drop(rx);
        let mut fanout = CaptureFanout::create_file(&path).unwrap().with_live(tx);
        let report = fanout.ingest(&[12_000; 320]).unwrap();
        assert!(report.live_dropped);
        assert_eq!(report.file_samples, 320);
        drop(fanout);
        let pcm = preprocess_path(&path).unwrap();
        assert_eq!(pcm.samples.len(), 320);
        cleanup(&path);
    }

    #[test]
    fn full_live_channel_does_not_block_or_lose_the_file() {
        let path = temp_wav("full-live");
        let mut fanout = CaptureFanout::create_file(&path).unwrap();
        let (fanout_with_live, _rx) = fanout.with_bounded_live(1);
        fanout = fanout_with_live;
        let first = fanout.ingest(&[1; 16]).unwrap();
        assert!(first.live_accepted);
        let second = fanout.ingest(&[2; 16]).unwrap();
        assert!(second.live_dropped);
        assert_eq!(second.file_samples, 32);
        drop(fanout);
        let pcm = preprocess_path(&path).unwrap();
        assert_eq!(pcm.samples.len(), 32);
        cleanup(&path);
    }
}
