//! Provisional live speaker activity for visualization (`P1`).
//!
//! Turn-taking heuristic on VAD utterance boundaries — not persona recognition.
//! Post-recording diarization may reconcile assignments.

/// One contiguous speech span attributed to a provisional speaker index.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct SpeakerActivitySlice {
    pub speaker_index: u8,
    pub start_ms: u64,
    pub end_ms: u64,
    pub peak_energy: f32,
}

/// Tracks provisional speaker lanes for the live activity timeline.
#[derive(Clone, Debug, Default)]
pub struct SpeakerActivityTracker {
    slices: Vec<SpeakerActivitySlice>,
    active_speaker: u8,
    last_utterance_end_ms: u64,
    long_gap_ms: u64,
}

impl SpeakerActivityTracker {
    pub fn new(long_gap_ms: u64) -> Self {
        Self {
            slices: Vec::new(),
            active_speaker: 0,
            last_utterance_end_ms: 0,
            long_gap_ms,
        }
    }

    pub fn slices(&self) -> &[SpeakerActivitySlice] {
        &self.slices
    }

    pub fn active_speaker_index(&self) -> u8 {
        self.active_speaker
    }

    /// Commits one stable utterance and returns the provisional speaker index.
    pub fn on_utterance(
        &mut self,
        start_ms: u64,
        end_ms: u64,
        peak_energy: f32,
    ) -> u8 {
        if self.last_utterance_end_ms > 0 {
            let gap = start_ms.saturating_sub(self.last_utterance_end_ms);
            if gap >= self.long_gap_ms {
                self.active_speaker = (self.active_speaker + 1) % 2;
            }
        }
        let speaker = self.active_speaker;
        self.slices.push(SpeakerActivitySlice {
            speaker_index: speaker,
            start_ms,
            end_ms,
            peak_energy,
        });
        self.last_utterance_end_ms = end_ms;
        speaker
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn first_utterance_is_speaker_zero() {
        let mut tracker = SpeakerActivityTracker::new(1200);
        assert_eq!(tracker.on_utterance(0, 1000, 0.2), 0);
    }

    #[test]
    fn long_gap_toggles_speaker_for_turn_taking() {
        let mut tracker = SpeakerActivityTracker::new(500);
        assert_eq!(tracker.on_utterance(0, 1000, 0.2), 0);
        assert_eq!(tracker.on_utterance(2000, 3000, 0.3), 1);
        assert_eq!(tracker.on_utterance(5000, 6000, 0.25), 0);
    }
}
