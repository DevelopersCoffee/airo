# AIRO Engineering Standards

This document serves as the architectural constitution for AIRO, ensuring we build an **offline-first AI productivity platform** (not just a meeting app).

## Architecture Decisions
- **Offline-First**: All models, knowledge bases, and document ingestion must support local/offline execution seamlessly.
- **Strict Service Layer**: Business logic must reside in service layers (e.g., `litert_lm_service.dart`) independent of UI.
- **Shared Download Manager**: All large assets (Whisper, LLMs, embeddings) must funnel through a centralized, progressive download system.

## Engineering Practices
- **Resumability**: Every background task must be resumable.
- **Recoverability**: Every download must be recoverable (never restart from zero).
- **Cancellable AI**: Every expensive operation or AI task must be cancellable and expose live progress.
- **Integrity**: Every model must support hash/integrity verification.
- **Migrations**: Every database schema change must include safe migrations.

## UI/UX Principles
- **Standardization**: Reduce visual inconsistency; standardize all core components (buttons, dialogs).
- **Progressive Disclosure**: Show complexity only when the user asks for it.
- **Functional Animation**: Keep animations strictly functional to guide the user, not just for aesthetics.
- **Frictionless UI**: Background AI processing must never block the main UI thread.

## Platform Capabilities Priority
AIRO prioritizes scalable platform capabilities over one-off features:
- RAG infrastructure
- Local model manager
- Vector databases
- Remote inference abstractions
