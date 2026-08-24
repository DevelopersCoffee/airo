//! Transcript stabilizer: PARTIAL → STABLE → FINAL without UI flicker.

use airo_mind_core::engine::{TranscriptSegment, TranscriptSegmentState};

/// Tracks committed vs hypothesis text for one live session.
pub struct TranscriptStabilizer {
    segment_index: usize,
    committed: Vec<TranscriptSegment>,
    hypothesis: Option<TranscriptSegment>,
}

impl Default for TranscriptStabilizer {
    fn default() -> Self {
        Self::new()
    }
}

impl TranscriptStabilizer {
    pub fn new() -> Self {
        Self {
            segment_index: 0,
            committed: Vec::new(),
            hypothesis: None,
        }
    }

    pub fn committed(&self) -> &[TranscriptSegment] {
        &self.committed
    }

    pub fn hypothesis(&self) -> Option<&TranscriptSegment> {
        self.hypothesis.as_ref()
    }

    /// A new engine window produced text. Emits [`Partial`] updates for the
    /// active tail; does not rewrite already-stable text.
    pub fn on_engine_segment(&mut self, segment: TranscriptSegment) -> Vec<TranscriptSegment> {
        let partial = TranscriptSegment::new(
            segment.start_ms,
            segment.end_ms,
            segment.text,
            TranscriptSegmentState::Partial,
        );
        self.hypothesis = Some(partial.clone());
        vec![partial]
    }

    /// Silence boundary: promote the current hypothesis to [`Stable`].
    pub fn on_speech_ended(&mut self) -> Vec<TranscriptSegment> {
        let Some(hyp) = self.hypothesis.take() else {
            return Vec::new();
        };
        let stable = TranscriptSegment::new(
            hyp.start_ms,
            hyp.end_ms,
            hyp.text,
            TranscriptSegmentState::Stable,
        );
        self.committed.push(stable.clone());
        self.segment_index += 1;
        vec![stable]
    }

    /// Session close: promote every [`Stable`] segment to [`Final`].
    pub fn finalize(&mut self) -> Vec<TranscriptSegment> {
        let mut out = Vec::new();
        if let Some(hyp) = self.hypothesis.take() {
            let stable = TranscriptSegment::new(
                hyp.start_ms,
                hyp.end_ms,
                hyp.text,
                TranscriptSegmentState::Stable,
            );
            self.committed.push(stable);
            self.segment_index += 1;
        }
        for seg in &self.committed {
            if seg.state == TranscriptSegmentState::Stable {
                out.push(TranscriptSegment::new(
                    seg.start_ms,
                    seg.end_ms,
                    seg.text.clone(),
                    TranscriptSegmentState::Final,
                ));
            }
        }
        for seg in &mut self.committed {
            if seg.state == TranscriptSegmentState::Stable {
                seg.state = TranscriptSegmentState::Final;
            }
        }
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn partial_then_stable_on_speech_end() {
        let mut s = TranscriptStabilizer::new();
        let partials = s.on_engine_segment(TranscriptSegment::final_text(0, 500, "hello".into()));
        assert_eq!(partials.len(), 1);
        assert_eq!(partials[0].state, TranscriptSegmentState::Partial);

        let stable = s.on_speech_ended();
        assert_eq!(stable.len(), 1);
        assert_eq!(stable[0].state, TranscriptSegmentState::Stable);
        assert_eq!(s.committed().len(), 1);
    }

    #[test]
    fn finalize_promotes_stable_to_final() {
        let mut s = TranscriptStabilizer::new();
        s.on_engine_segment(TranscriptSegment::final_text(0, 500, "done".into()));
        s.on_speech_ended();
        let finals = s.finalize();
        assert_eq!(finals.len(), 1);
        assert_eq!(finals[0].state, TranscriptSegmentState::Final);
        assert_eq!(s.committed()[0].state, TranscriptSegmentState::Final);
    }
}
