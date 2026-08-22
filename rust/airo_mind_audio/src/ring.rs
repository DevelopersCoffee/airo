//! Bounded PCM ring for live speech ingestion (`ZC-3`).

use crate::TARGET_SAMPLE_RATE;

/// A fixed-capacity ring of `i16` PCM samples. When full, the oldest samples
/// are dropped (drop-oldest), never unbounded growth.
pub struct PcmRingBuffer {
    data: Vec<i16>,
    head: usize,
    len: usize,
    dropped_samples: u64,
}

/// Result of pushing samples into the ring.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct RingPushReport {
    pub accepted: usize,
    pub dropped: usize,
}

impl PcmRingBuffer {
    pub fn with_capacity_samples(capacity: usize) -> Self {
        Self {
            data: vec![0; capacity.max(1)],
            head: 0,
            len: 0,
            dropped_samples: 0,
        }
    }

    /// Capacity in samples (not bytes).
    pub fn capacity(&self) -> usize {
        self.data.len()
    }

    pub fn len(&self) -> usize {
        self.len
    }

    pub fn is_empty(&self) -> bool {
        self.len == 0
    }

    pub fn dropped_samples(&self) -> u64 {
        self.dropped_samples
    }

    pub fn push(&mut self, samples: &[i16]) -> RingPushReport {
        let mut accepted = 0;
        let mut dropped = 0;
        for sample in samples {
            if self.len == self.data.len() {
                self.head = (self.head + 1) % self.data.len();
                self.len -= 1;
                self.dropped_samples += 1;
                dropped += 1;
            }
            let tail = (self.head + self.len) % self.data.len();
            self.data[tail] = *sample;
            self.len += 1;
            accepted += 1;
        }
        RingPushReport { accepted, dropped }
    }

    /// Oldest-to-newest view of the retained samples.
    pub fn contiguous(&self) -> Vec<i16> {
        if self.len == 0 {
            return Vec::new();
        }
        let mut out = Vec::with_capacity(self.len);
        for i in 0..self.len {
            let idx = (self.head + i) % self.data.len();
            out.push(self.data[idx]);
        }
        out
    }

    /// Last `max_samples` retained, oldest-to-newest within that tail.
    pub fn tail(&self, max_samples: usize) -> Vec<i16> {
        let take = max_samples.min(self.len);
        if take == 0 {
            return Vec::new();
        }
        let start = self.len - take;
        let mut out = Vec::with_capacity(take);
        for i in start..self.len {
            let idx = (self.head + i) % self.data.len();
            out.push(self.data[idx]);
        }
        out
    }

    pub fn clear(&mut self) {
        self.head = 0;
        self.len = 0;
    }

    /// Duration of retained audio in milliseconds at 16 kHz.
    pub fn retained_ms(&self) -> u64 {
        self.len as u64 * 1000 / TARGET_SAMPLE_RATE as u64
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn push_and_tail_returns_latest_samples() {
        let mut ring = PcmRingBuffer::with_capacity_samples(8);
        ring.push(&[1, 2, 3, 4]);
        assert_eq!(ring.tail(2), vec![3, 4]);
        assert_eq!(ring.contiguous(), vec![1, 2, 3, 4]);
    }

    #[test]
    fn overflow_drops_oldest_and_counts_drops() {
        let mut ring = PcmRingBuffer::with_capacity_samples(4);
        let report = ring.push(&[1, 2, 3, 4, 5, 6]);
        assert_eq!(report.dropped, 2);
        assert_eq!(ring.dropped_samples(), 2);
        assert_eq!(ring.contiguous(), vec![3, 4, 5, 6]);
    }
}
