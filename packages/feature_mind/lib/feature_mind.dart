/// Airo Mind — a local-first personal intelligence runtime.
///
/// Two layers are exported here. The **runtime** is the port a surface binds
/// to: eight sub-ports, their models, and two implementations. The **meeting
/// recorder** is what shipped before the runtime existed, and it keeps working
/// while milestone 22 builds the real surfaces around it.
///
/// The generated bridges are not exported and must not be reached: a consumer
/// that imports `src/whisper/`, `src/llama/` or `frb_generated` has coupled
/// itself to a code generator's output. Only `rust_mind_runtime.dart` may touch
/// them.
///
/// There are two bridges because there are two engine libraries — whisper.cpp
/// and llama.cpp vendor incompatible copies of ggml and cannot share a linked
/// image (#1546). That split is an implementation detail: it stops at
/// `MindService`, and the names exported here are unchanged.
library;

export 'src/mind_availability.dart';

export 'src/whisper/api/meetings.dart'
    show MeetingRecord, SearchHit, SpeechLanguage;
export 'src/meeting_screen.dart' show MeetingScreen;
export 'src/mind_home_screen.dart' show MindHomeScreen, meetingListPreview;
export 'src/export/application/meeting_export_service.dart'
    show MeetingExportService;
export 'src/export/domain/meeting_export_models.dart'
    show MeetingExportBundle;
export 'src/mind_indic_intelligence.dart'
    show
        MindIndicCapability,
        MindIndicGenerationMode,
        MindIndicPreferences,
        MindIndicSpeechMode,
        kMindIndicMinAvailableRamBytes,
        kMindIndicMinTotalRamBytes,
        pinnedIndicGenerationModel;

export 'src/mind_model_advisor.dart'
    show
        MindModelAdvisor,
        MindModelRecommendation,
        MindModelRecommendationAction,
        MindModelRecommendationBadge,
        MindModelRecommendationSeverity,
        MindScribeModelIds,
        MindScribeStackRecommendation;

export 'src/mind_scribe_models_panel.dart'
    show
        mindScribeServiceProvider,
        MindScribeModelsPanel,
        scribeCatalogIdToFileName;

export 'src/settings/indic_generation_settings_tile.dart'
    show IndicGenerationSettingsTile;
export 'src/settings/indic_speech_backend_settings_tile.dart'
    show IndicSpeechBackendSettingsTile;
export 'src/settings/indic_intelligence_preferences.dart'
    show indicGenerationModeProvider, indicSpeechModeProvider;
export 'src/settings/mind_entitlements_provider.dart'
    show mindEntitlementsProvider;
export 'src/mind_service.dart'
    show MindProgress, MindService, MindStage, MindStatus, MindUnavailable;

// Path A of the STT/TTS half of task-based model routing
// (`tasks/mind-stt-tts-routing-plan.md`): a truthful availability answer for
// core_ai's AiTask.speechToText/textToSpeech, not a chooser -- there is
// exactly one speech engine and no TTS engine to choose between.
export 'src/speech_task_availability.dart';

// Scribe semantic search (#508): store + ranker. MindService.search() is the
// product call site; indexMeetingForSearch / SemanticSearchRanker.indexMeeting
// are the Wave 2 Agent G seams for chat-over-meetings.
export 'src/search/meeting_embedding_store.dart';
export 'src/search/meeting_text_chunker.dart';
export 'src/search/semantic_search_ranker.dart';

// Module contract + host seam + routes — the assistant hub, merged in from
// `feature_assistant` (`docs/superpowers/plans/2026-08-07-airo-mind-ssot-plan.md`,
// Phase 2).
export 'src/mind_module.dart';
export 'src/host/assistant_host_adapter.dart';
export 'src/routing/assistant_route_names.dart';

// Global hotkey registration + per-OS permission flow (#1455). Infrastructure
// for Quick Capture (#1454) and the macOS Everything Browser (#1461); no
// per-OS backend ships yet, see UnsupportedGlobalHotkeyPort's doc comment.
export 'src/host/hotkey/global_hotkey_port.dart';
export 'src/host/hotkey/global_hotkey_registrar.dart';
export 'src/host/hotkey/hotkey_combination.dart';
export 'src/host/hotkey/hotkey_permission_state.dart';
export 'src/host/hotkey/hotkey_registration_outcome.dart';
export 'src/host/hotkey/hotkey_request.dart';

// Assistant hub + tools
export 'src/assistant/assistant_surface_policy.dart'
    show AssistantSurfacePolicy, assistantSurfacePolicyProvider;
export 'src/assistant/presentation/screens/assistant_screen.dart';
export 'src/assistant/presentation/screens/audio_scribe_screen.dart';
export 'src/assistant/presentation/screens/mobile_actions_screen.dart';
export 'src/assistant/presentation/screens/prompt_lab_screen.dart';

// Agent chat + model management
export 'src/agent_chat/application/assistant_model_preferences.dart';
export 'src/agent_chat/application/assistant_runtime_readiness.dart';
export 'src/agent_chat/data/services/agent_notification_scheduler.dart';
export 'src/agent_chat/data/services/assistant_runtime_service.dart';
export 'src/agent_chat/data/services/chat_history_store.dart';
export 'src/agent_chat/data/services/notification_navigation_service.dart';
export 'src/agent_chat/domain/models/agent_skill.dart';
export 'src/agent_chat/domain/models/assistant_model_selection.dart';
export 'src/agent_chat/domain/models/assistant_runtime_ids.dart';
export 'src/agent_chat/domain/models/chat_models.dart';
export 'src/agent_chat/domain/models/chat_response_metadata.dart';
export 'src/agent_chat/domain/services/agent_skill_registry.dart';
export 'src/agent_chat/presentation/screens/agent_skills_screen.dart';
export 'src/agent_chat/presentation/screens/chat_screen.dart';
export 'src/agent_chat/presentation/screens/device_capability_report_screen.dart';
export 'src/agent_chat/presentation/screens/model_advisor_screen.dart';
export 'src/agent_chat/presentation/screens/model_health_center_screen.dart';
export 'src/agent_chat/presentation/screens/model_library_screen.dart';
export 'src/agent_chat/presentation/screens/notifications_screen.dart';
export 'src/agent_chat/presentation/screens/profile_screen.dart';

// Wellbeing
export 'src/wellbeing/presentation/screens/wellbeing_screen.dart';

// Quotes
export 'src/quotes/presentation/widgets/daily_quote_card.dart';
export 'src/quotes/domain/models/quote_model.dart';
export 'src/quotes/domain/models/quote_preferences.dart';
export 'src/quotes/domain/services/quote_service.dart';
export 'src/quotes/application/providers/quote_provider.dart';

// Assistant-only services
export 'src/services/local_runtime_preloader_service.dart';
export 'src/services/model_preload_preferences.dart';
export 'src/services/voice_search_service.dart';
export 'src/services/device_actions_service.dart';
export 'src/services/llama_gguf_service.dart';

// Model acquisition. A shell composes `DownloadModelProvider` with its own
// `downloadUrlFor` (hosting is a Dart-side decision, `ADR-0018 §1` — the
// registry pins a digest, not a URL) and passes it to `MindService`. Neither
// this package nor the shell is required to use it: `ModelInstaller` (the
// bundled-asset default) still works unchanged.
export 'src/model_installer.dart' show ModelInstaller;
export 'src/models/desktop_mind_model_provider.dart'
    show DesktopMindModelProvider;
export 'src/models/download_model_provider.dart' show DownloadModelProvider;
export 'src/models/model_provider.dart'
    show
        InstalledModel,
        ModelAcquisitionDone,
        ModelAcquisitionEvent,
        ModelAcquisitionProgress,
        ModelProvider,
        RequiredModel;
// The pinned registry itself, for a shell that needs the same list a provider
// needs — the Mind shell's model explorer reports install state per pinned
// file (#1556) without going through a provider to get it. Lives in the
// model-descriptor boundary adapter (#1673) alongside the rest of the
// bridge <-> RequiredModel/InstalledModel/OfflineModelInfo translation.
export 'src/models/model_descriptor_adapter.dart'
    show
        pinnedRequiredModels,
        mindScribeRequiredModels,
        mindIndicOptionalModels,
        mindDiarizeOptionalModels,
        pinnedEcapaDiarizeModel,
        kMindEcapaOnnxFileName,
        pinnedMultilingualSpeechModel,
        offlineModelInfoFromRequiredModel;

// Model download manager (#1457): progress in bytes, mobile-data pause,
// storage budget — built on `ModelPort` rather than on `ModelProvider`
// above, which is the older bundled/download acquisition path.
export 'src/models/byte_format.dart';
export 'src/models/model_download_connectivity.dart';
export 'src/models/model_download_coordinator.dart';
export 'src/models/model_download_state.dart';
export 'src/models/model_management_panel.dart';

// Runtime — models.
export 'src/runtime/models/capability_models.dart';
export 'src/runtime/models/context_models.dart';
export 'src/runtime/models/log_models.dart';
export 'src/runtime/models/mesh_models.dart';
export 'src/runtime/models/model_models.dart';
export 'src/runtime/models/portability_models.dart';
export 'src/runtime/models/projection_models.dart';
export 'src/runtime/models/vault_models.dart';

// Runtime — the port milestone 19 implements against.
export 'src/runtime/mind_runtime.dart';
export 'src/runtime/ports/capability_port.dart';
export 'src/runtime/ports/context_port.dart';
export 'src/runtime/ports/mesh_port.dart';
export 'src/runtime/ports/model_port.dart';
export 'src/runtime/ports/operation_log_port.dart';
export 'src/runtime/ports/portability_port.dart';
export 'src/runtime/ports/projection_port.dart';
export 'src/runtime/ports/vault_port.dart';

// Runtime — the deterministic fixture every surface is built against.
export 'src/runtime/fixture/fixture_data.dart';
export 'src/runtime/fixture/fixture_mind_runtime.dart';
export 'src/runtime/rust/rust_mind_runtime.dart';
export 'src/runtime/persistent/persistent_operation_log.dart'
    show LazyPersistentOperationLog, sharedMindOperationLog;
export 'src/library_loader.dart'
    show initializeLlamaBridge, initializeWhisperBridge, isLlamaLoaded, isWhisperLoaded;

// Portability -- surface 08's ".airobackup" envelope-sealing flow: pick
// contexts, set the phrase, choose a destination on your own network.
export 'src/portability/backup_envelope_controller.dart';
export 'src/portability/backup_envelope_state.dart';
export 'src/portability/destination_validation.dart';

// Surface 13 — Windows/Linux Runtime Console (#1460).
export 'src/runtime_console/runtime_console_availability.dart';
export 'src/runtime_console/runtime_console_controller.dart';
export 'src/runtime_console/runtime_console_models.dart';
export 'src/runtime_console/runtime_console_table.dart';

// Runtime — the ⌘K summon seam. #1455 lands the real OS-level global hotkey
// separately; see the doc comment on MindGlobalShortcut for how the two
// reconcile.
export 'src/runtime/mind_global_shortcut.dart';

// Surface 06 — Capability Packs. Installed list/detail bound to
// CapabilityPort; the drafter (#1250) and marketplace (#1247, #1251) regions
// render disabled — milestone 20 fills them in without a redesign.
export 'src/capability_packs/presentation/screens/capability_detail_screen.dart';
export 'src/capability_packs/presentation/screens/capability_packs_screen.dart';

// Widgets that carry the design rules. Every Mind surface uses these rather
// than re-implementing a pip or a number strip that drifts from the rule.
export 'src/widgets/mind_context_chip.dart';
export 'src/widgets/mind_number_strip.dart';
// `formatBytes` here collides with `src/models/byte_format.dart`'s function
// of the same name (pre-existing, unrelated to #1673 — fixed only because it
// broke `flutter analyze`'s ambiguous_export gate this issue's acceptance
// criteria require clean). Neither name is used unqualified through this
// barrel today; every in-package caller imports its specific file directly.
export 'src/widgets/format_bytes.dart' hide formatBytes;
export 'src/widgets/mind_op_row.dart';
export 'src/widgets/mind_palette.dart';
export 'src/widgets/mind_presence_pip.dart';
export 'src/widgets/relative_time.dart';
export 'src/widgets/mind_projection_switcher.dart';

// Surface 11 — the macOS Everything Browser (#1461): ⌘K palette, three
// columns, native menu bar.
export 'src/widgets/mind_everything_browser.dart';
export 'src/widgets/mind_command_palette_scope.dart';
export 'src/widgets/mind_native_menu_bar.dart';

// #1774 trust UX — multilingual / language badge + honest offline copy on
// scribe and meeting surfaces. Complements #1664 without shipping the pin UI.
export 'src/trust/scribe_trust_state.dart';
export 'src/trust/scribe_trust_signals.dart';

// Provenance — on-device entity extraction and the Inspector (surfaces 09
// and 11, issue #1463).
export 'src/provenance/domain/models/extracted_entity.dart';
export 'src/provenance/domain/services/entity_extractor.dart';
export 'src/provenance/presentation/widgets/entity_chip.dart';
export 'src/provenance/presentation/widgets/provenance_inspector.dart';

// Surfaces — the phone screens of the device system.
export 'src/surfaces/capabilities_surface.dart';
export 'src/surfaces/devices_surface.dart';
export 'src/surfaces/memory_surface.dart';
export 'src/surfaces/mind_home_surface.dart';
export 'src/surfaces/portability_surface.dart';
export 'src/surfaces/mind_surface_scaffold.dart';
export 'src/surfaces/context_workspace_surface.dart';

// The runtime skeleton (#1338): Operation → Persist → Replay → Projection
// through a minimal Notes capability, proving the vertical slice end to end.
// Not yet wired into `mind_module.dart`'s routes -- this is the architecture
// proof, not a shipped journey. The Rust-side twin
// (`rust/airo_mind_core/src/{runtime,notes}.rs`) is what registers through
// the real `#1302` Supervisor/EngineRegistry; this Dart half is an
// independent implementation of the same contract, not yet bridged to it
// through FFI (see the module docs on `NotesOperationLog` for why).
export 'src/notes/domain/note.dart';
export 'src/notes/domain/notes_operation.dart';
export 'src/notes/domain/notes_operation_log.dart';
export 'src/notes/domain/notes_projection.dart';
export 'src/notes/notes_capability.dart';
export 'src/notes/presentation/notes_screen.dart';

// In-app meeting audio capture + resumable background processing (#1656).
// Feeds `meetings.dart`'s `transcribeRecording`/`saveMeeting` (the ".m4a in"
// pipeline) with a file this package now records itself, instead of only
// accepting one that already exists on disk.
export 'src/capture/domain/meeting_recording_state.dart';
export 'src/capture/domain/audio_retention_policy.dart';
export 'src/capture/domain/speech_language_mode.dart';
export 'src/capture/domain/meeting_processing_job.dart';
export 'src/capture/data/audio_recorder_port.dart';
export 'src/capture/data/meeting_recording_service_gateway.dart';
export 'src/capture/data/meeting_processing_queue_store.dart';
export 'src/capture/application/meeting_capture_controller.dart';
export 'src/capture/application/meeting_processing_queue.dart';
export 'src/capture/application/meeting_processing_job_runner.dart';
export 'src/capture/application/meeting_capture_providers.dart';
export 'src/capture/application/audio_retention_preference.dart';
export 'src/capture/application/speech_language_preference.dart';
export 'src/capture/presentation/meeting_capture_screen.dart';
export 'src/capture/presentation/audio_retention_settings_tile.dart';
export 'src/capture/presentation/speech_language_settings_tile.dart';
