# AIRO Architecture Map

This document maps the major subsystems required for AIRO to function as an offline-first AI productivity platform.

| Subsystem | Introduced in Release | Current Maturity | Dependencies | AIRO Priority | Planned Implementation Phase |
| :--- | :--- | :--- | :--- | :--- | :--- |
| UI Framework | v0.0.2 | Stable | None | Critical | MVP |
| Navigation | v0.0.2 | Stable | UI Framework | Critical | MVP |
| ModelManager | v0.0.2 | Experimental | ModelInstallationService, Storage | Critical | MVP |
| ModelInstallationService | Recent | Stable | Storage Layer | Critical | MVP |
| PackageManifestParser | Recent | Stable | None | Critical | MVP |
| DependencyValidator | Recent | Stable | None | Critical | MVP |
| ImportWizard | Recent | Stable | ModelInstallationService | High | v1 |
| DownloadWatchdog | Recent | Stable | ModelInstallationService | High | v1 |
| InstallationRecoveryManager | Recent | Stable | Storage Layer | High | v1 |
| InstallationDiagnosticsService | Recent | Stable | ModelInstallationService | Medium | v2 |
| BackgroundInstallationWorker | Recent | Stable | InstallationRecoveryManager | Critical | MVP |
| ModelCapabilityDatabase | Recent | Stable | ModelRegistry | Critical | MVP |
| ModelRegistry | Recent | Stable | Storage Layer | Critical | MVP |
| Document Processing Pipeline | v0.0.2-v0.0.43 | Stable | Storage Layer | Critical | MVP |
| Offline RAG Pipeline | v0.0.2-v0.0.43 | Experimental | Vector Database, Storage | Critical | MVP |
| Vector Database Layer | v0.0.2-v0.0.43 | Stable | Storage Layer | Critical | MVP |
| Local Embedding Service | v0.0.2-v0.0.43 | Stable | AI Runtime | Critical | MVP |
| Conversation Queue | v0.0.2-v0.0.43 | Stable | Background Worker | Critical | MVP |
| AI Runtime | v0.0.2 | Stable | Model Manager | High | v1 |
| STT Pipeline | v0.0.2 | Stable | AI Runtime, Audio Service | High | v1 |
| TTS Pipeline | v0.0.2 | Experimental | AI Runtime | Medium | v2 |
| Semantic Search Engine | v0.0.2-v0.0.43 | Stable | Vector Database | High | v1 |
| Knowledge Base | v0.0.2-v0.0.43 | Experimental | Vector Database, Storage | Critical | MVP |
| Conversation Memory | v0.0.2 | Experimental | Vector Database | High | v2 |
| Storage Layer | v0.0.2 | Production | None | Critical | MVP |
| Sync Layer | v0.0.2 | Experimental | Storage Layer, Auth | High | v2 |
| Analytics | v0.0.2 | Experimental | Storage Layer | Low | Future |
| Settings | v0.0.2 | Stable | Storage Layer | Medium | MVP |
| Plugin System | v0.0.2 | Experimental | AI Runtime | Low | Future |
| Model Metadata Registry | v0.0.2-v0.0.43 | Stable | Storage Layer | Critical | MVP |
| Design Token System | v0.0.2-v0.0.43 | Stable | UI Framework | Critical | MVP |
| KeyboardManager | v0.0.44-v0.0.48 | Stable | UI Framework | Critical | MVP |
| ThemeManager | v0.0.44-v0.0.48 | Stable | UI Framework | High | v1 |
| DeviceCapabilityService | v0.0.44-v0.0.48 | Stable | None | High | v1 |
| PromptTemplateRegistry | v0.0.44-v0.0.48 | Stable | AI Runtime | Critical | MVP |
| PlatformBehaviorService | v0.0.44-v0.0.48 | Stable | None | Critical | MVP |
| UnifiedInputFramework | v0.0.44-v0.0.48 | Stable | UI Framework | High | v1 |
| RuntimeCompatibilityService | v0.0.49+ | Stable | DeviceCapabilityService | Critical | MVP |
| ModelCompatibilityEngine | v0.0.49+ | Stable | RuntimeCompatibilityService | Critical | MVP |
| RuntimeRecommendationEngine | v0.0.49+ | Experimental | ModelCompatibilityEngine | Critical | MVP |
| MemoryPersistenceService | v0.0.49+ | Stable | Storage Layer | Critical | MVP |
| PrivacyManager | v0.0.49+ | Stable | Storage Layer | Critical | MVP |
| ComplianceManager | v0.0.49+ | Stable | PlatformBehaviorService | Critical | MVP |
| DistributionManager | v0.0.49+ | Stable | None | Critical | MVP |
| RuntimeConfigurationService | v0.0.49+ | Stable | Settings | Critical | MVP |
| ToolRegistry | Recent | Stable | AI Runtime | Critical | MVP |
| ToolExecutionEngine | Recent | Stable | ToolRegistry, AI Runtime | Critical | MVP |
| AdaptiveContextManager | Recent | Stable | RuntimeMemoryManager | High | v1 |
| RuntimeMemoryManager | Recent | Stable | DeviceIntelligenceEngine | High | v1 |
| DeviceIntelligenceEngine | Recent | Stable | None | Critical | MVP |
| InferenceProfileManager | Recent | Stable | DeviceIntelligenceEngine | High | v1 |
| PlatformRuntimeAdapters | Recent | Stable | DeviceIntelligenceEngine | High | v1 |
| BackgroundJobScheduler | Recent | Production | Storage Layer | High | v1 |
| VisionService | Recent | Stable | AI Runtime | High | v1 |
| URLIngestionPipeline | Recent | Experimental | VisionService, Storage | High | v1 |
| TelemetryManager | Recent | Stable | None | High | v1 |
| NotificationManager | Recent | Stable | PlatformBehaviorService | High | v1 |
| CapabilityRegistry | Recent | Stable | AI Runtime | Critical | MVP |
| WorkspaceManager | Recent | Stable | Storage Layer | Critical | MVP |
| WorkspaceConfigurationService | Recent | Stable | WorkspaceManager | Critical | MVP |
| KnowledgeService | Recent | Stable | Storage Layer, WorkspaceManager | High | v1 |
| SearchEngine | Recent | Stable | Vector Database, Storage Layer | High | v1 |
| ThinkingProfileManager | Recent | Experimental | CapabilityRegistry | High | v1 |
| AIProvider | Recent | Stable | AI Runtime | Critical | MVP |
| AIControlCenter | Recent | Stable | TelemetryManager, RuntimeConfigurationService | High | v1 |
| StartupOrchestrator | Recent | Stable | None | Critical | MVP |
| DiscoveryService | Recent | Stable | None | Critical | MVP |
| ContextManager | Recent | Stable | Storage Layer | Critical | MVP |
| AttachmentPipeline | Recent | Stable | ContextManager | High | v1 |
| NetworkIntelligenceService | Recent | Stable | PlatformBehaviorService | Medium | v2 |
| StreamingEngine | Recent | Stable | None | Medium | v2 |
| ProviderLifecycleManager | Recent | Stable | AIProvider | High | v1 |
| NativeRuntimeBridge | Recent | Stable | None | Critical | MVP |
| HealthMonitor | Recent | Stable | None | High | v1 |
| ModelSourceRegistry | Recent | Stable | ModelRegistry | Medium | v2 |
| ModelBrowserService | Recent | Stable | ModelRegistry | Medium | v2 |
| LazyInitializationManager | Latest | Stable | None | Critical | MVP |
| RecommendationEngine | Latest | Stable | DeviceCapabilityService | Medium | v2 |
| BackendSelector | Latest | Stable | None | High | v1 |
| RepairManager | Latest | Stable | Storage Layer | High | v1 |
| WorkspaceIsolationService | Latest | Stable | WorkspaceManager | Critical | MVP |
| DeviceProfileManager | Latest | Stable | DeviceCapabilityService | Medium | v2 |
| PersistentJobStore | Latest | Stable | Storage Layer | Critical | MVP |
