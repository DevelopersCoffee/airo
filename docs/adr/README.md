# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records for the Airo project.

## What is an ADR?

An Architecture Decision Record (ADR) captures an important architectural decision made along with its context and consequences. We use the [MADR](https://adr.github.io/madr/) (Markdown Any Decision Records) format.

## Index

| ID | Title | Status | Date |
|----|-------|--------|------|
| [0001](0001-package-structure.md) | Modular Package Structure | Accepted | 2025-11-30 |
| [0002](0002-state-management.md) | Riverpod for State Management | Accepted | 2025-11-30 |
| [0003](0003-offline-first.md) | Offline-First Architecture | Accepted | 2025-11-30 |
| [0004](0004-ai-abstraction.md) | AI Provider Abstraction Layer | Accepted | 2025-11-30 |

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

