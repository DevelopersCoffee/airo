# AIRO Architecture Map

This document maps the major subsystems required for AIRO to function as a complete **offline-first AI Operating System**.

## 1. Runtime
| Subsystem | Current Maturity | Dependencies | AIRO Priority | Planned Phase |
| :--- | :--- | :--- | :--- | :--- |
| RuntimeOrchestrator | Stable | EngineRegistry | Critical | MVP |
| ModelResidencyManager | Stable | DeviceCapabilityService | Critical | MVP |
| RuntimeScheduler | Stable | RuntimeOrchestrator | Critical | MVP |
| SessionManager | Stable | RuntimeOrchestrator | Critical | MVP |
| EngineRegistry | Stable | NativeRuntimeBridge | Medium | v2 |
| NativeRuntimeBridge | Stable | None | Critical | MVP |
| AIProvider | Stable | EngineRegistry | Critical | MVP |
| PlatformRuntimeAdapters | Stable | EngineRegistry | High | v1 |
| AdaptiveContextManager | Stable | ModelResidencyManager | High | v1 |
| ContextManager | Stable | Storage Layer | Critical | MVP |
| LazyInitializationManager | Stable | None | Critical | MVP |

## 2. Intelligence
| Subsystem | Current Maturity | Dependencies | AIRO Priority | Planned Phase |
| :--- | :--- | :--- | :--- | :--- |
| WorkflowEngine | Stable | RuntimeOrchestrator | High | v1 |
| CapabilityRegistry | Stable | RuntimeOrchestrator | Critical | MVP |
| KnowledgeService | Stable | WorkspaceManager | High | v1 |
| SearchEngine | Stable | Vector Database Layer | High | v1 |
| EmbeddingService | Stable | RuntimeOrchestrator | Critical | MVP |
| Document Processing Pipeline | Stable | Storage Layer | Critical | MVP |
| Vector Database Layer | Stable | Storage Layer | Critical | MVP |
| VisionService | Stable | RuntimeOrchestrator | High | v1 |
| URLIngestionPipeline | Experimental | VisionService | High | v1 |
| Semantic Search Engine | Stable | Vector Database Layer | High | v1 |
| ThinkingProfileManager | Experimental | CapabilityRegistry | High | v1 |

## 3. Audio
| Subsystem | Current Maturity | Dependencies | AIRO Priority | Planned Phase |
| :--- | :--- | :--- | :--- | :--- |
| VoicePlatform | Stable | RuntimeOrchestrator | High | v1 |
| SpeakerManager | Experimental | VoicePlatform | High | v1 |
| AudioPipeline | Stable | VoicePlatform | High | v1 |
| TTSService | Experimental | RuntimeOrchestrator | Medium | v2 |
| STT Pipeline | Stable | VoicePlatform | High | v1 |

## 4. Models
| Subsystem | Current Maturity | Dependencies | AIRO Priority | Planned Phase |
| :--- | :--- | :--- | :--- | :--- |
| ModelInstallationService | Stable | Storage Layer | Critical | MVP |
| ModelRegistry | Stable | Storage Layer | Critical | MVP |
| RecommendationEngine | Stable | DeviceCapabilityService | Medium | v2 |
| BackendSelector | Stable | DeviceCapabilityService | High | v1 |
| ModelCapabilityDatabase | Stable | ModelRegistry | Critical | MVP |
| PackageManifestParser | Stable | None | Critical | MVP |
| DependencyValidator | Stable | None | Critical | MVP |
| ImportWizard | Stable | ModelInstallationService | High | v1 |
| DownloadWatchdog | Stable | ModelInstallationService | High | v1 |
| InstallationRecoveryManager | Stable | Storage Layer | High | v1 |
| BackgroundInstallationWorker | Stable | InstallationRecoveryManager | Critical | MVP |

## 5. Extensibility
| Subsystem | Current Maturity | Dependencies | AIRO Priority | Planned Phase |
| :--- | :--- | :--- | :--- | :--- |
| PluginFramework | Experimental | CapabilityRegistry | Medium | v2 |
| ToolRegistry | Stable | RuntimeOrchestrator | Critical | MVP |
| ProviderManager | Stable | AIProvider | Medium | v2 |
| ToolExecutionEngine | Stable | ToolRegistry | Critical | MVP |
| ProviderLifecycleManager | Stable | AIProvider | High | v1 |

## 6. Operations
| Subsystem | Current Maturity | Dependencies | AIRO Priority | Planned Phase |
| :--- | :--- | :--- | :--- | :--- |
| DiagnosticsService | Stable | TelemetryService | Medium | v2 |
| HealthMonitor | Stable | None | High | v1 |
| TelemetryService | Stable | None | High | v1 |
| RepairManager | Stable | Storage Layer | High | v1 |
| AIControlCenter | Stable | TelemetryService | High | v1 |
| StartupOrchestrator | Stable | None | Critical | MVP |
| DiscoveryService | Stable | None | Critical | MVP |
| BackgroundJobScheduler | Production | Storage Layer | High | v1 |
| PersistentJobStore | Stable | Storage Layer | Critical | MVP |
| WorkspaceIsolationService | Stable | Storage Layer | Critical | MVP |
| DeviceProfileManager | Stable | DeviceCapabilityService | Medium | v2 |

## 7. Core Platform (Legacy / Base)
| Subsystem | Current Maturity | Dependencies | AIRO Priority | Planned Phase |
| :--- | :--- | :--- | :--- | :--- |
| UI Framework | Stable | None | Critical | MVP |
| Navigation | Stable | UI Framework | Critical | MVP |
| Storage Layer | Production | None | Critical | MVP |
| ThemeManager | Stable | UI Framework | High | v1 |
| KeyboardManager | Stable | UI Framework | Critical | MVP |
| DeviceCapabilityService | Stable | None | High | v1 |
| WorkspaceManager | Stable | Storage Layer | Critical | MVP |
