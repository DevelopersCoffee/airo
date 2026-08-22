# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records for the Airo project.

## What is an ADR?

An Architecture Decision Record (ADR) captures an important architectural decision made along with its context and consequences. We use the [MADR](https://adr.github.io/madr/) (Markdown Any Decision Records) format.

## Index

| ID | Title | Status | Date |
|----|-------|--------|------|
| [0001](0001-package-structure.md) | Modular Package Structure | Accepted | 2025-11-30 |
| [0006](0006-mobile-ui-governance-and-shell-ownership.md) | Mobile UI Governance and Shell Ownership | Accepted | 2026-06-27 |
| [0008](0008-storage-tiering-and-preference-size-guards.md) | Storage Tiering and Preference Size Guards | Accepted | 2026-07-15 |
| [0009](0009-airo-coin-vault-crypto.md) | Airo Coin vault crypto design and threat model | Accepted | 2026-07-20 |
| [0010](0010-airo-coin-package-first-development.md) | Airo Coin package-first development | Accepted | 2026-07-22 |
| [0011](0011-super-app-modular-shell-ssot.md) | Super-app modular shell SSOT | Proposed | 2026-07-24 |
| [0012](0012-edge-intelligence-media-boundary.md) | Edge intelligence and media-engine boundary | Accepted | 2026-07-27 |
| [0018](0018-airo-arena-game-intelligence-packs.md) | Airo Arena as game intelligence packs on the existing edge runtime | Proposed | 2026-08-01 |
| [0023](0023-mind-reliability-checkpoints-in-process.md) | Mind reliability checkpoints stay in-process | Accepted | 2026-08-22 |
| [0024](0024-reliability-checkpoints-prefs-tier.md) | Reliability checkpoint metadata uses the Prefs tier | Accepted | 2026-08-22 |
| [0025](0025-streaming-speech-engine-boundary.md) | `SpeechEngine` gains a streaming session, and stays PCM-pure | Proposed | 2026-08-22 |

## Creating a New ADR

1. Copy `template.md` to a new file: `NNNN-title-with-dashes.md`
2. Fill in all sections
3. Update this index
4. Submit a PR for review

## ADR Lifecycle

- **Proposed**: Under discussion
- **Accepted**: Approved and implemented
- **Deprecated**: No longer applies
- **Superseded**: Replaced by another ADR

## Related Documents

- [Architecture Overview](../architecture/README.md)
- [Package Structure](../architecture/package-structure.md)
