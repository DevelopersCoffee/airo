# Planned: AI Director, Highlights, and Sports Command Center

Status: Planned design for Airo TV Pro; no v0.0.5 implementation or
availability claim.

## Customer outcomes

- AI Director proposes the most relevant feed among user-authorized sources.
- AI Highlights builds a short recap from material the user may legally
  access; it does not copy or host media.
- Sports Command Center presents synchronized user-authorized feeds, fixtures,
  and alerts with source provenance.

## Data requirements

Director needs bounded playback diagnostics, programme/fixture identity,
explicit user preferences, and available-feed metadata. Highlights additionally
needs legal seek/index access plus event markers; absent rights or markers, it
must return unavailable rather than synthesize footage. Sports requires
licensed/public fixture facts, time-zone normalization, and channel carriage
resolution.

No raw playlist credentials, private URLs, faces, voiceprints, or viewing
history leave the device without explicit cloud consent. Every recommendation
records source and confidence; no “popular” claim is inferred from local data.

## Device/cloud split

On-device code owns source eligibility, diagnostics, preference filtering,
final playback choice, and fail-closed execution through `IntentCommand`.
Cloud is optional for licensed fixture enrichment or compute-heavy highlight
analysis and receives opaque media/event references only under consent.
Playback remains local and fully functional when Pro or cloud is unavailable.

## Entitlement gates

Before implementation, add reviewed stable `ProFeature` IDs for
`ai_director`, `ai_highlights`, and `sports_command_center`. Each private
`ProModule` initializes after first frame only when entitled. This requires the
planned entitlement lifecycle and cancellable-worker contracts in ADR 0014;
the current one-shot registry/executor are insufficient. Entry points,
background work, network calls, and stored derived artifacts check the same
entitlement generation before side effects. Revocation fences late results and
deletes transient and persisted Pro-derived data without touching CE
favorites, playlists, history, or authorized source material.

## Failure and evaluation

Unsupported rights, missing provenance, stale fixtures, ambiguous event
identity, insufficient confidence, or device pressure produce a visible
unavailable/manual state. Evaluation requires decision precision, false-alert
rate, latency, thermal/memory budget, accessibility, rights review, and
physical multi-feed playback evidence. Concepts stay Planned until those gates
and a public artifact exist.
