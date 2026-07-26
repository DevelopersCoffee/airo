# Planned: Co-Watcher, AI Timeline, and AI Accessibility

Status: Planned design for Airo TV Pro. Accessibility fundamentals remain
Community Edition and are never entitlement-gated.

## Customer outcomes

- AI Co-Watcher offers optional contextual notes without interrupting media.
- AI Timeline exposes searchable, sourced programme moments when lawful index
  data exists.
- AI Accessibility proposes enhanced descriptions, summaries, or simplified
  navigation beyond the CE baseline.

## Data requirements

Inputs may include EPG/metadata provenance, captions supplied with authorized
media, playback position, explicit interaction mode, and user accessibility
preferences. The system does not upload raw audio/video, captions, or voice
input by default. Generated statements retain source/confidence and are
visually distinguished from publisher-supplied facts.

## Device/cloud split

On-device code owns playback timing, caption alignment, screen-reader
semantics, reduced-motion behavior, and interruption policy. Optional cloud
generation requires explicit consent and minimized excerpts with a finite
retention policy. If the model, network, rights, or confidence gate fails, CE
captions, focus order, TalkBack, and manual controls continue unchanged.

## Entitlement gates

Proposed IDs are `ai_co_watcher`, `ai_timeline`, and
`ai_accessibility_enhancements`. Only additive generated experiences are
gated. WCAG semantics, captions supplied by the source, contrast, focus,
remote navigation, and error recovery are CE invariants. Private modules must
stop/fence generation through ADR 0014's planned lifecycle and cancellable-job
contracts. Revocation deletes all transient and persisted Pro-derived indexes,
summaries, embeddings, and preferences while retaining authorized source
metadata/captions and CE accessibility settings.

## Safety and evaluation

Evaluation covers hallucination/citation accuracy, caption timing, spoiler
controls, interruption rate, screen-reader operation, language coverage,
child-profile safety, deletion, and reduced-motion behavior. Accessibility
reviewers can veto launch even when model metrics pass.
