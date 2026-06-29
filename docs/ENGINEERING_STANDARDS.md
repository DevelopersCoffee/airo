# AIRO Engineering Standards

This document serves as the architectural constitution for AIRO, ensuring we build an **offline-first AI productivity platform** (not just a meeting app).

## Architecture Decisions
- **Offline-First**: All models, knowledge bases, and document ingestion must support local/offline execution seamlessly.
- **Strict Service Layer**: Business logic must reside in service layers (e.g., `litert_lm_service.dart`) independent of UI.
- **Model Installation Is a Platform Service:** A single `ModelInstallationService` must own downloads, local imports, dependencies, validation, and recovery.
- **Service-Based Architecture**: Avoid monolithic logic; split distinct capabilities (Embeddings, RAG, STT) into isolated services.
- **Runtime Isolation (Micro-Runtimes):** Separate AI implementations by capability. OCR, Speech, and LLMs must operate as independent micro-runtimes.
- **Workspace-Centric Design:** Meetings do not exist independently; they belong to a workspace that owns knowledge, memory, and search.
- **Workspace Isolation:** Strict boundary preventing state leakage; creating a new workspace must always start with clean state.
- **Provider Independence:** All AI requests must route through an AIProvider interface to support future LAN/Cloud execution without changing feature logic.
- **Native Code Must Be Isolated:** Wrap native AI runtimes behind safe boundaries (NativeRuntimeBridge) that handle memory cleanup and thread coordination to prevent app crashes.
- **Capability-Driven Architecture:** AI capabilities must declare hardware requirements. The application configures itself based on the selected model capabilities. Avoid model-specific conditions (`if model == "Gemma"`). Depend entirely on capabilities (`if supportsToolCalling`).
- **Vector Database Layer**: Must use a centralized vector database for all embeddings and semantic search.
- **Build Platform Services:** Avoid screen-specific fixes; build centralized managers (KeyboardManager, ThemeManager).

## Engineering Practices (Features Worth Copying)
- **Delay Work Until Necessary (Lazy Initialization):** Do not create expensive resources (meetings, AI contexts, indices) until the user takes a meaningful action.
- **Automatic Recovery (RepairManager):** Build self-healing infrastructure that automatically repairs missing files, hashes, and interrupted installations without user intervention.
- **Metadata-Driven Recommendations:** Model rankings must come from telemetry and hardware capability, not alphabetical lists.
- **Resumability**: Every background task must be resumable. Use a robust Persistent Job Store.
- **Recoverability**: Every download must be recoverable (never restart from zero). Any operation over a few seconds must survive app crashes, reboots, and network switches.
- **Cancellable AI**: Every expensive operation or AI task must be cancellable and expose live progress.
- **Integrity**: Every model must support hash/integrity verification.
- **Migrations**: Every database schema change must include safe migrations.
- **Streaming Response Batching**: Batch UI updates during token generation to improve FPS, lower CPU, and reduce battery usage.
- **Native Platform Abstractions**: Use platform-native sharing and avoid custom non-standard bridging where OS APIs exist.
- **Quality Gates**: Mandate End-to-End UI Tests, CI Quality Gates, and an Automated Release Pipeline.
- **Progressive Feature Rollout**: Do not release massive features universally; use feature flags or phased releases.
- **Progressive Feature Exposure**: Only show UI for features supported by the currently loaded runtime capabilities.
- **Standardize AI Models:** All models must implement a common interface (Metadata, Templates, Hardware reqs). Abstract model implementations to expose a single runtime interface regardless of the underlying LLM.
- **Documentation as a Feature:** Maintain architecture docs alongside the codebase.
- **Capability Validation Before Execution:** Never assume hardware support; always validate runtime constraints before model loading. Perform validation before execution instead of recovering from failures afterward.
- **Persist Only Stable Data:** Only save long-term knowledge, avoiding temporary runtime states.
- **Build for Future Distribution:** Distribution logic should never leak into application logic.
- **Continuous Compliance:** Run permission, privacy, and store policy checks via CI.
- **Tool Registry:** Centralized registry for local capabilities (Search, Calculate, OCR) so adding future tools is straightforward.
- **Treat Security as a Platform Capability:** Every tool should execute inside a controlled sandbox environment with explicit permission checks and resource limits. Secure External Data by validating imported URLs/documents before processing to prevent SSRF.
- **Optimize for Failure:** Expect low memory, thermal throttling, unsupported hardware, and interrupted downloads. Graceful degradation is preferable to runtime failures.
- **Build Adaptive Defaults:** The platform must auto-configure the best model, backend, context length, and inference profile based on current hardware and thermal states rather than requiring manual configuration.
- **Startup Should Never Block:** The UI must become interactive immediately. Heavy initializations belong in background orchestrators (Phased startup).
- **Centralize Prompt Construction:** Only the Context Manager builds prompts, avoiding prompt inconsistency across features.
- **Design for Asynchrony:** Never assume synchronous initialization for networks, providers, or discoveries.
- **Build for Consumer Reliability:** Assume users will close the app, lose connectivity, and import incomplete files.

## UI/UX Principles
- **Standardization**: Reduce visual inconsistency; standardize all core components (buttons, dialogs). Use a strict Design Token System and Shared UI Components.
- **Progressive Disclosure**: Show complexity only when the user asks for it (e.g. Chat Settings moved to accordions/bottom sheets).
- **Functional Animation**: Keep animations strictly functional to guide the user (Expand, Collapse, Progress, Navigation, Recording state), not just for aesthetics.
- **Frictionless UI**: Background AI processing must never block the main UI thread. Queue multiple requests rather than executing simultaneously.
- **Dynamic Theme**: Must properly support Light, Dark, and System out of the box.

## Platform Capabilities Priority
AIRO prioritizes scalable platform capabilities over one-off features:
- Model Packaging & Installation Lifecycle
- Orchestration Layers (Startup, Discovery, Context)
- Capability Registry & Workspace Manager
- Document Processing Pipeline (OCR, chunking)
- Offline RAG Pipeline & Semantic Search
- Local Model Manager (with intelligent routing)
- Vector Databases
- Tool Execution Engine & Sandbox
- AI Provider Abstraction (Local/Network/Cloud)
