import 'dart:async';

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core_ai/core_ai.dart';
import 'package:core_ui/core_ui.dart';
import 'package:platform_calendar/platform_calendar.dart';
import '../../../host/assistant_host_adapter.dart';
import '../../../assistant/assistant_surface_policy.dart';
import '../../../agent_chat/data/connectors/calendar_connector.dart';
import '../../../agent_chat/data/connectors/date_time_connector.dart';
import '../../../agent_chat/data/connectors/life_track_status_connector_factory.dart';
import '../../../agent_chat/data/connectors/notification_connector.dart';
import '../../../agent_chat/data/connectors/route_connector.dart';
import '../../../agent_chat/data/built_in_skills/wellbeing.dart';
import '../../../agent_chat/data/services/assistant_chat_context_builder.dart';
import '../../../agent_chat/data/services/assistant_grounded_reply.dart';
import '../../../agent_chat/data/services/diet_plan_plugin_prompt.dart';
import '../../../agent_chat/data/services/chat_history_store.dart';
import '../../../widgets/mind_desktop_chrome.dart';
import '../../../widgets/mind_palette.dart';
import '../../../widgets/mind_presence_pip.dart';
import '../../../agent_chat/data/services/assistant_runtime_service.dart';
import '../../../agent_chat/data/services/gguf_instruct_prompt.dart';
import '../../../agent_chat/data/services/selected_runtime_agent_skill_model_client.dart';
import '../../../agent_chat/application/assistant_model_preferences.dart';
import '../../../agent_chat/domain/models/agent_skill.dart';
import '../../../agent_chat/domain/models/assistant_runtime_ids.dart';
import '../../../agent_chat/domain/models/chat_response_metadata.dart';
import '../../../agent_chat/domain/models/grounded_citation.dart';
import '../../../agent_chat/domain/services/agent_connector.dart';
import '../../../agent_chat/domain/services/agent_connector_registry.dart';
import '../../../agent_chat/domain/services/agent_skill_orchestrator.dart';
import '../../../agent_chat/domain/services/agent_skill_registry.dart';
import '../../../agent_chat/domain/services/agent_tool_interceptor.dart';
import '../../../agent_chat/domain/services/intent_parser.dart';
import '../../../agent_chat/domain/services/persona_session.dart';
import '../../../agent_chat/domain/services/tool_registry.dart';
import '../../../agent_chat/presentation/widgets/fallback_notification.dart';
import '../../../agent_chat/presentation/widgets/grounded_answer_block.dart';
import '../../../agent_chat/presentation/widgets/manage_skills_sheet.dart';
import '../../../agent_chat/presentation/widgets/mind_safety_banner.dart';
import '../../../agent_chat/presentation/widgets/pick_assistant_sheet.dart';
import '../../../agent_chat/presentation/widgets/skill_action_trace_card.dart';
import '../../../reasoning/chat_reasoning_request.dart';
import '../../../reasoning/reasoning_models.dart';
import '../../../reasoning/reasoning_progress_panel.dart';
import '../../../reasoning/reasoning_tool_loop.dart';
import '../../../bridges/mind_generation_bridge.dart';
import '../../../runtime/fixture/fixture_mind_runtime.dart';
import '../../../runtime/models/capability_models.dart';
import '../../../runtime/ports/operation_log_port.dart';
import '../../application/assistant_runtime_readiness.dart';
import '../../../services/local_runtime_preloader_service.dart';
import '../../../services/model_preload_preferences.dart';
import '../../../services/voice_search_service.dart';
import '../../../intelligence/ai_profile.dart';
import '../../../intelligence/intelligence_providers.dart';
import '../../../intelligence/intelligence_typography.dart';
import '../../../intelligence/profile_customize_sheet.dart';
import '../../../widgets/mind_op_row.dart';
import 'chat_automatic_gate.dart';
import 'model_library_screen.dart';

/// A single bubble in [ChatScreen]'s transcript — the UI-rendering shape
/// (text/isUser/traces/metadata/citations/groundingState/safetyClass), not
/// the persistence shape in `domain/models/chat_models.dart`'s `ChatMessage`
/// (id/conversationId/role/content/toolCalls). The two used to share the name
/// `ChatMessage`, forced apart only by a `hide ChatMessage` in the package
/// barrel. Renamed here (#1673) rather than merged: the fields don't map
/// 1:1, and `chat_models.dart`'s `ChatMessage`/`ChatConversation` have no
/// other caller today, so folding this screen's live, well-tested model into
/// that one would have been a blind, lossy swap.
class AgentChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<AgentActionTrace> traces;
  final ChatResponseMetadata? metadata;

  /// Ops this answer was replayed from. See [groundingState].
  final List<GroundedCitation> citations;

  /// Whether [text] is backed by a real logged op. Defaults to
  /// [GroundingState.notApplicable] — most messages (the welcome text, a
  /// navigation confirmation, an error) carry no factual claim to ground.
  final GroundingState groundingState;

  /// The safety banner this answer's capability requires, if any.
  final CapabilitySafetyClass? safetyClass;

  final bool pendingCalendarPermission;

  /// Stage labels from a reasoning pass. Never raw model thoughts.
  final List<ReasoningProgressStep> reasoningSteps;
  final String? reasoningSummary;
  final MindReasoningLevel? reasoningLevel;
  final bool reasoningInProgress;
  final List<ChatHistoryToolCall> reasoningToolCalls;

  AgentChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.traces = const [],
    this.metadata,
    this.citations = const [],
    this.groundingState = GroundingState.notApplicable,
    this.safetyClass,
    this.pendingCalendarPermission = false,
    this.reasoningSteps = const [],
    this.reasoningSummary,
    this.reasoningLevel,
    this.reasoningInProgress = false,
    this.reasoningToolCalls = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  ChatHistoryEntry toHistoryEntry() => ChatHistoryEntry(
    text: text,
    isUser: isUser,
    timestamp: timestamp,
    reasoningSummary: isUser ? null : reasoningSummary,
    reasoningLevel: isUser ? null : reasoningLevelStableId(reasoningLevel),
    toolCalls: isUser ? const [] : reasoningToolCalls,
  );

  static AgentChatMessage fromHistoryEntry(ChatHistoryEntry entry) =>
      AgentChatMessage(
        text: entry.text,
        isUser: entry.isUser,
        timestamp: entry.timestamp,
        reasoningSummary: entry.reasoningSummary,
        reasoningLevel: reasoningLevelFromStableId(entry.reasoningLevel),
        reasoningToolCalls: entry.toolCalls,
      );
}

String formatChatTranscript(Iterable<AgentChatMessage> messages) {
  final buffer = StringBuffer('Airo chat transcript');
  for (final message in messages) {
    final text = message.text.trimRight();
    if (text.isEmpty) continue;
    final speaker = message.isUser ? 'User' : 'Airo';
    buffer
      ..writeln()
      ..writeln()
      ..writeln('$speaker:')
      ..write(text);
  }
  return buffer.toString();
}

/// Agent chat screen
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.assistantRuntimeService,
    this.localRuntimePreloader,
    this.skillOrchestrator,
    this.enableAiInitialization = true,
    this.initialMessages,
    this.initialDraft,
    this.initialPinnedPersonaId,
    this.operationLogPort,
    this.calendarService,
    this.generationBridge,
    this.useOnDeviceReasoning,
    this.reasoningDeviceTier,
    this.deviceSignalsProbe,
  });

  final AssistantRuntimeService? assistantRuntimeService;
  final LocalRuntimePreloaderService? localRuntimePreloader;
  final AgentSkillOrchestrator? skillOrchestrator;
  final bool enableAiInitialization;
  final List<AgentChatMessage>? initialMessages;
  final String? initialDraft;
  final String? initialPinnedPersonaId;

  /// Grounds skill answers in the log. Defaults to `FixtureMindRuntime().log`
  /// so the surface always has a real, if fixture-backed, log to cite —
  /// swap in `RustMindRuntime().log` once M19 lands the real runtime.
  final OperationLogPort? operationLogPort;
  final CalendarService? calendarService;
  final MindGenerationBridge? generationBridge;

  /// Test seam. Production uses [shouldUseOnDeviceReasoning].
  final bool Function()? useOnDeviceReasoning;
  final LlmDeviceTier? reasoningDeviceTier;
  final LlmDeviceSignalsProbe? deviceSignalsProbe;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late TextEditingController _messageController;
  final ScrollController _messageScrollController = ScrollController();
  final List<AgentChatMessage> _messages = [];
  final ChatHistoryStore _chatHistoryStore = ChatHistoryStore();
  Timer? _historyPersistTimer;
  bool _historyRestored = false;
  final ToolRegistry _toolRegistry = ToolRegistry();
  AgentSkillRegistry _skillRegistry = AgentSkillRegistry();
  late final AgentConnectorRegistry _connectorRegistry;
  final GeminiNanoService _geminiNano = GeminiNanoService();
  final LiteRtLmService _liteRtLm = LiteRtLmService();
  late final AssistantRuntimeService _assistantRuntime;
  late final LocalRuntimePreloaderService _localRuntimePreloader;
  late final MindGenerationBridge _generationBridge;
  LlmDeviceTier _reasoningTier = LlmDeviceTier.large;
  LlmDeviceSignals? _reasoningSignals;
  late AgentSkillOrchestrator _skillOrchestrator;
  late final OperationLogPort _operationLogPort;
  final AssistantChatContextBuilder _chatContextBuilder =
      const AssistantChatContextBuilder(maxMessageChars: 1200);
  Map<String, dynamic>? _pendingCalendarEvent;
  String? _pinnedPersonaId;
  String? _pendingCalendarPermissionPrompt;
  bool _isDeviceSupported = false;
  bool _isGenerating = false;
  bool _isCapturingVoice = false;

  final FocusNode _selectedModelBarFocusNode = FocusNode();
  final FocusNode _skillsButtonFocusNode = FocusNode();
  final FocusNode _messageInputFocusNode = FocusNode();
  final FocusNode _sendButtonFocusNode = FocusNode(canRequestFocus: false);

  @override
  void initState() {
    super.initState();
    _pinnedPersonaId = widget.initialPinnedPersonaId;
    _messageController = TextEditingController(text: widget.initialDraft ?? '');
    _connectorRegistry = _buildConnectorRegistry();
    _operationLogPort = widget.operationLogPort ?? FixtureMindRuntime().log;
    _moveComposerCursorToEnd();
    _assistantRuntime =
        widget.assistantRuntimeService ??
        AssistantRuntimeService(
          geminiNano: _geminiNano,
          liteRtLm: _liteRtLm,
          loadAssistantModelLibrary: () =>
              ref.read(assistantModelLibraryProvider.future),
        );
    _generationBridge = widget.generationBridge ?? RustMindGenerationBridge();
    _localRuntimePreloader =
        widget.localRuntimePreloader ??
        LocalRuntimePreloaderService(
          preloadPreferences: SharedPreferencesModelPreloadPreferences(),
          geminiNano: _geminiNano,
          liteRtLm: _liteRtLm,
          loadAssistantModelLibrary: () =>
              ref.read(assistantModelLibraryProvider.future),
          selectedModelId: () => ref.read(selectedAssistantModelIdProvider),
          isGenerationActive: () => _isGenerating,
        );
    _skillOrchestrator =
        widget.skillOrchestrator ?? _buildSkillOrchestrator(_skillRegistry);
    if (widget.skillOrchestrator == null) {
      _loadPersistedSkillRegistry();
    }
    // Add welcome message
    _messages.addAll(
      widget.initialMessages ??
          [
            AgentChatMessage(
              text:
                  'Hi! I can chat, use enabled skills, check your schedule, split bills, draft diet plans, plan routines, and open Airo tools from here.',
              isUser: false,
            ),
          ],
    );
    if (widget.enableAiInitialization) {
      _initializeAI();
      if (widget.initialMessages == null) {
        unawaited(_restoreChatHistory());
      }
    }
    unawaited(initializeLifeTrackStatusConnector());
    MindChatMenuActions.attach(
      this,
      newChat: () => unawaited(_clearConversation(confirm: false)),
      exportChat: () => unawaited(_copyTranscript()),
      clearChat: () => unawaited(_confirmClearConversation()),
    );
  }

  AgentConnectorRegistry _buildConnectorRegistry() {
    final calendar = widget.calendarService ?? createCalendarService();
    final connectors = <AgentConnector>[
      DateTimeConnector(),
      NativeCalendarPermissionConnector(calendar: calendar),
      NativeCalendarConnector(calendar: calendar),
      NativeCreateCalendarEventConnector(),
      ScheduleNotificationConnector(),
      RouteConnector(),
      GuideBreathingConnector(),
      LogReflectionConnector(),
    ];
    final lifeTrackStatusConnector = createLifeTrackStatusConnector();
    if (lifeTrackStatusConnector != null) {
      connectors.add(lifeTrackStatusConnector);
    }
    return AgentConnectorRegistry(connectors: connectors);
  }

  AgentSkillOrchestrator _buildSkillOrchestrator(AgentSkillRegistry registry) {
    return AgentSkillOrchestrator(
      skillRegistry: registry,
      connectorRegistry: _connectorRegistry,
      modelClient: SelectedRuntimeAgentSkillModelClient(
        runtimeService: _assistantRuntime,
        selectedModelId: () => ref.read(selectedAssistantModelIdProvider),
      ),
      useFallbackModelClient: true,
      preferDeterministicSkills: true,
      operationLogPort: _operationLogPort,
    );
  }

  Future<void> _loadPersistedSkillRegistry() async {
    final registry = await AgentSkillRegistry.loadPersisted();
    if (!mounted) return;
    setState(() {
      _skillRegistry = registry;
      _skillOrchestrator = _buildSkillOrchestrator(registry);
    });
  }

  Future<void> _initializeAI() async {
    try {
      // Gemini Nano is an Android/AICore capability. Avoid probing the native
      // channel on desktop and web hosts (including Flutter widget tests),
      // where there is no platform implementation to answer the request.
      // Besides avoiding needless work, this prevents an orphaned timeout
      // timer when a test/widget is torn down before an unsupported channel
      // call completes.
      if (!ref.read(assistantHostAdapterProvider).isAndroidHost) {
        if (mounted) {
          setState(() {
            _isDeviceSupported = false;
          });
        }
        unawaited(_preloadLocalRuntimes());
        return;
      }

      // Check device support
      final isSupported = await _geminiNano.isSupported();

      if (mounted) {
        setState(() {
          _isDeviceSupported = isSupported;
        });
      }

      unawaited(_preloadLocalRuntimes());

      // Show bottom banner popup
      if (mounted) {
        _showBottomBanner();
      }
    } catch (e) {
      debugPrint('Error initializing AI: $e');
    }
  }

  Future<void> _preloadLocalRuntimes() async {
    final report = await _localRuntimePreloader.preloadSelectedModels();
    debugPrint(
      'Local preload completed: '
      '${report.entries.map((entry) => '${entry.runtimeId}:${entry.reason}').join(', ')}',
    );
  }

  void _showBottomBanner() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isDeviceSupported ? Icons.phone_android : Icons.cloud,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isDeviceSupported
                        ? 'Optimized for Your Device'
                        : 'Choose AI Runtime',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _isDeviceSupported
                        ? 'On-device AI ready - fast and private'
                        : 'On-device AI is not available here',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _isDeviceSupported
            ? Colors.green.shade700
            : Colors.orange.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    MindChatMenuActions.detach(this);
    _selectedModelBarFocusNode.dispose();
    _skillsButtonFocusNode.dispose();
    _messageInputFocusNode.dispose();
    _sendButtonFocusNode.dispose();
    _messageScrollController.dispose();
    _localRuntimePreloader.abortPreload();
    unawaited(closeLifeTrackStatusConnector());
    _messageController.dispose();
    _historyPersistTimer?.cancel();
    if (_historyRestored) {
      unawaited(
        _chatHistoryStore.save(
          _messages.map((message) => message.toHistoryEntry()),
        ),
      );
    }
    super.dispose();
  }

  Future<void> _restoreChatHistory() async {
    final history = await _chatHistoryStore.load();
    if (!mounted) return;
    setState(() {
      _historyRestored = true;
      if (history.isNotEmpty) {
        _messages
          ..clear()
          ..addAll(history.map(AgentChatMessage.fromHistoryEntry));
      }
    });
  }

  void _scheduleHistoryPersist() {
    if (!_historyRestored) return;
    _historyPersistTimer?.cancel();
    _historyPersistTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(
        _chatHistoryStore.save(
          _messages.map((message) => message.toHistoryEntry()),
        ),
      );
    });
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _scheduleHistoryPersist();
  }

  void _moveComposerCursorToEnd() {
    _messageController.selection = TextSelection.collapsed(
      offset: _messageController.text.length,
    );
  }

  void _restoreComposerFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _messageInputFocusNode.requestFocus();
      _moveComposerCursorToEnd();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Map<String, String>>(intelligenceOverridesProvider, (
      previous,
      next,
    ) {
      final catalog = ref.read(intelligenceCatalogProvider);
      final readiness = const AiProfileResolver().resolve(
        AiProfile.generalChat,
        catalog,
        overrides: next,
      );
      final model = readiness.slots.first.selection.model;
      if (model == null || !model.isDownloaded) return;
      final id = assistantModelIdForOfflineModel(model.id);
      if (ref.read(selectedAssistantModelIdProvider) == id) return;
      unawaited(ref.read(selectedAssistantModelIdProvider.notifier).select(id));
    });

    final selectedAssistantModelId = ref.watch(
      selectedAssistantModelIdProvider,
    );

    if (selectedAssistantModelId == null) {
      final library = ref.watch(assistantModelLibraryProvider);
      return library.when(
        loading: () => const AiroResponsiveScaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => AiroResponsiveScaffold(
          errorMessage: error.toString(),
          onRetry: () => ref.invalidate(assistantModelLibraryProvider),
          body: const SizedBox.shrink(),
        ),
        data: (state) => ChatAutomaticGate(
          library: state,
          onModelSelected: _selectAssistantModel,
          onOpenModelManager: _openModelManager,
        ),
      );
    }

    // A persisted selection must not make an unavailable local runtime look
    // active. This can happen after an app update, model removal, or when a
    // device exposes the LiteRT channel without a configured model path. Let
    // the model picker explain the required setup instead of showing a stale
    // "model on device" chat surface.
    final library = ref.watch(assistantModelLibraryProvider);
    final selectedCandidate = library.maybeWhen(
      data: (state) => state.candidateById(selectedAssistantModelId),
      orElse: () => null,
    );
    if (library.hasValue &&
        (selectedCandidate == null ||
            (selectedCandidate.local && !selectedCandidate.available))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final current = ref.read(selectedAssistantModelIdProvider);
        if (current == selectedAssistantModelId) {
          unawaited(
            ref.read(selectedAssistantModelIdProvider.notifier).select(null),
          );
        }
      });
      return const AiroResponsiveScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // No AppBar here - global AppBar is in AppShell
    final colorScheme = Theme.of(context).colorScheme;
    final readiness = ref.watch(assistantRuntimeReadinessProvider);
    final canSend = readiness.canSend && !_isGenerating;
    final session = _personaSession;
    return AiroResponsiveScaffold(
      backgroundColor: Colors.transparent,
      body: ref
          .read(assistantHostAdapterProvider)
          .wrapWithDictionarySelection(
            child: Column(
              children: [
                _buildSelectedModelBar(selectedAssistantModelId),
                if (session.isPinned) _buildPinnedAssistantBar(session),

                // Messages list
                Expanded(
                  child: ListView.builder(
                    key: const Key('agent_chat_message_list'),
                    controller: _messageScrollController,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount:
                        _messages.length +
                        (_shouldShowPromptSuggestions ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildSamplePrompts();
                      }

                      final message = _messages[index];
                      return _buildMessage(message, index);
                    },
                  ),
                ),

                // Input area
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.34),
                    border: Border(
                      top: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        key: const Key('agent_chat_skills_button'),
                        focusNode: _skillsButtonFocusNode,
                        onPressed: _showManageSkills,
                        icon: const Icon(Icons.auto_fix_high, size: 18),
                        label: const Text('Skills'),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: _isCapturingVoice
                            ? 'Stop voice input'
                            : 'Speak message',
                        child: IconButton(
                          key: const Key('agent_chat_voice_button'),
                          tooltip: _isCapturingVoice
                              ? 'Stop voice input'
                              : 'Speak message',
                          onPressed: _captureVoice,
                          icon: Icon(
                            _isCapturingVoice ? Icons.stop : Icons.mic_none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const Key('agent_chat_input'),
                          focusNode: _messageInputFocusNode,
                          controller: _messageController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) {
                            _sendMessage();
                            _restoreComposerFocus();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        key: const Key('agent_chat_send_button'),
                        focusNode: _sendButtonFocusNode,
                        onPressed: canSend ? _sendMessage : null,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  PersonaSession get _personaSession => PersonaSession(
    pinned: _pinnedPersonaId == null
        ? null
        : _skillRegistry.getById(_pinnedPersonaId!),
  );

  Widget _buildPinnedAssistantBar(PersonaSession session) {
    final persona = session.pinned!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            key: const Key('agent_chat_pinned_assistant_label'),
            'Assistant: ${persona.name}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          MindSafetyBanner(safetyClass: session.safetyClass),
        ],
      ),
    );
  }

  bool get _shouldShowPromptSuggestions {
    return !_messages.any((message) => message.isUser);
  }

  Future<void> _captureVoice() async {
    final service = ref.read(voiceSearchServiceProvider);
    if (_isCapturingVoice) {
      await service.stopListening();
      if (mounted) setState(() => _isCapturingVoice = false);
      return;
    }

    setState(() => _isCapturingVoice = true);
    VoiceSearchResult result;
    try {
      result = await service.startListening();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _isCapturingVoice = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Voice input failed. $error')));
      return;
    }
    if (!mounted) return;
    setState(() => _isCapturingVoice = false);
    if (result.isSuccess && result.text != null) {
      _messageController
        ..text = result.text!
        ..selection = TextSelection.collapsed(offset: result.text!.length);
      _messageInputFocusNode.requestFocus();
      return;
    }
    if (result.errorMessage != null && result.errorMessage!.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.errorMessage!)));
    }
  }

  Widget _buildSelectedModelBar(String selectedModelId) {
    final library = ref.watch(assistantModelLibraryProvider);
    final readiness = ref.watch(assistantRuntimeReadinessProvider);

    return library.maybeWhen(
      data: (state) {
        final candidate = state.candidateById(selectedModelId);
        final label = candidate?.name ?? 'Selected model';
        final runtime = candidate?.runtime ?? selectedModelId;
        final percent = (readiness.progress * 100).clamp(0, 100).round();
        final stats = _assistantRuntime.lastGenerationStats;
        final tok = stats != null && stats.tokensPerSecond > 0
            ? ' · ${stats.tokensPerSecond.toStringAsFixed(0)} TOK/S'
            : '';
        final isLocal = candidate?.local != false;
        final statusLine = readiness.canSend
            ? '${isLocal ? 'NO NETWORK' : runtime}$tok'
            : '${readiness.label} · $percent%';

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const BoxDecoration(
            color: MindPalette.surface,
            border: Border(bottom: BorderSide(color: MindPalette.grid)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  MindPresencePip(isLocal: isLocal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'AUTOMATIC',
                          style: IntelligenceTypography.status(),
                        ),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: MindPalette.ink,
                                letterSpacing: 0.8,
                              ),
                        ),
                        Text(
                          statusLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: MindPalette.local,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('agent_chat_assistants_button'),
                    tooltip: _personaSession.pinned?.name ?? 'Assistants',
                    onPressed: _showPickAssistant,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      _personaSession.isPinned
                          ? Icons.badge
                          : Icons.badge_outlined,
                      size: 20,
                    ),
                  ),
                  IconButton(
                    focusNode: _selectedModelBarFocusNode,
                    tooltip: 'Customize',
                    onPressed: _openChatCustomize,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.tune, size: 20),
                  ),
                  IconButton(
                    key: const Key('agent_chat_copy_transcript_button'),
                    tooltip: 'Copy transcript',
                    onPressed: _messages.isEmpty ? null : _copyTranscript,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.ios_share_outlined, size: 20),
                  ),
                  IconButton(
                    key: const Key('agent_chat_clear_conversation_button'),
                    tooltip: 'Clear chat',
                    onPressed: _messages.isEmpty || _isGenerating
                        ? null
                        : _confirmClearConversation,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                  ),
                ],
              ),
              if (!readiness.canSend && readiness.progress > 0) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: readiness.progress.clamp(0.0, 1.0),
                ),
              ],
              if (!readiness.canSend &&
                  readiness.phase ==
                      AssistantRuntimeReadinessPhase.blocked) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _openChatCustomize,
                      child: const Text('Customize'),
                    ),
                    FilledButton(
                      onPressed: () {
                        unawaited(
                          ref
                              .read(assistantRuntimeReadinessProvider.notifier)
                              .refresh(),
                        );
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildSamplePrompts() {
    final session = _personaSession;
    final personaPrompts = session.starterPrompts;
    if (personaPrompts.isNotEmpty) {
      final theme = Theme.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              'Try a prompt',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final prompt in personaPrompts)
                ActionChip(
                  key: Key('persona_starter_${prompt.hashCode}'),
                  label: Text(prompt),
                  onPressed: () {
                    _messageController.text = prompt;
                    _sendMessage();
                  },
                ),
            ],
          ),
        ],
      );
    }
    final policy = ref.watch(assistantSurfacePolicyProvider);
    final prompts = _toolRegistry.getSkillCards(policy: policy);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(
            'Try a prompt',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: prompts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final prompt = prompts[index];
              final color = _colorForSkill(prompt.key);

              return ActionChip(
                avatar: Icon(_iconForSkill(prompt.iconKey), size: 18),
                label: Text(prompt.title),
                side: BorderSide(color: color.withValues(alpha: 0.35)),
                backgroundColor: color.withValues(alpha: 0.08),
                onPressed: () {
                  _messageController.text = _promptForSkill(prompt);
                  _restoreComposerFocus();
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<bool> _handleParsedIntent(Intent intent) async {
    if (intent.type == IntentType.unknown) {
      return false;
    }

    if (intent.type == IntentType.boredom) {
      _handleBoredom();
      return true;
    }

    if (intent.type == IntentType.createDietPlan) {
      return false;
    }

    final toolResult = await _toolRegistry.executeIntent(intent);
    if (toolResult.isError) {
      return false;
    }

    setState(() {
      _messages.add(AgentChatMessage(text: toolResult.message, isUser: false));
    });
    _scrollMessagesToLatest();

    if (toolResult.shouldNavigate && mounted) {
      context.go(toolResult.route!, extra: toolResult.parameters);
    }
    return true;
  }

  Widget _buildMessage(AgentChatMessage message, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxWidth =
        MediaQuery.of(context).size.width *
        (message.traces.isNotEmpty || message.metadata != null ? 0.86 : 0.75);
    final canCopy = message.text.trim().isNotEmpty;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!message.isUser)
              MindSafetyBanner(safetyClass: message.safetyClass),
            if (message.traces.isNotEmpty)
              SkillActionTraceCard(traces: message.traces),
            if (!message.isUser)
              ReasoningProgressPanel(
                steps: message.reasoningSteps,
                inProgress: message.reasoningInProgress,
                summary: message.reasoningSummary,
              ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? colorScheme.primary.withValues(alpha: 0.16)
                    : colorScheme.surface.withValues(alpha: 0.72),
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ChatMessageBody(
                      text: message.text,
                      color: colorScheme.primary.withValues(alpha: 0.9),
                      onCopyCode: _copyMessageText,
                    ),
                  ),
                  if (canCopy) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      key: ValueKey('agent_chat_message_actions_$index'),
                      tooltip: 'Copy message',
                      onPressed: () => _copyMessageText(message.text),
                      icon: const Icon(Icons.copy_all, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                    ),
                    if (!message.isUser)
                      IconButton(
                        tooltip: 'Read message aloud',
                        onPressed: () => _readMessageAloud(message.text),
                        icon: const Icon(Icons.volume_up_outlined, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (!message.isUser && message.metadata != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('agent_chat_metadata_button'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showMetadataSheet(message),
                    icon: const Icon(Icons.query_stats, size: 16),
                    label: Text(_metadataSummary(message.metadata!)),
                  ),
                ),
              ),
            if (!message.isUser && message.pendingCalendarPermission)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton(
                  key: const Key('allow_calendar_access'),
                  onPressed: _allowCalendarAccess,
                  child: const Text('Allow Calendar Access'),
                ),
              ),
            if (!message.isUser)
              GroundedAnswerBlock(
                state: message.groundingState,
                citations: message.citations,
                onCitationTap: _showCitationSheet,
              ),
          ],
        ),
      ),
    );
  }

  /// Resolves a `GROUNDED IN` chip against the real log — rule R02, a
  /// context tag is never decorative. Shows the op the answer was replayed
  /// from rather than trusting the citation's own copy of that data.
  Future<void> _showCitationSheet(GroundedCitation citation) async {
    final op = await _operationLogPort.bySequence(citation.opSequence);
    if (!mounted) return;
    if (op == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Op ${citation.opSequence} no longer resolves.'),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: MindOpRow(op: op),
        ),
      ),
    );
  }

  Future<void> _copyMessageText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message copied')));
  }

  Future<void> _copyTranscript() async {
    final transcript = formatChatTranscript(_messages);
    await Clipboard.setData(ClipboardData(text: transcript));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transcript copied')));
  }

  Future<void> _readMessageAloud(String text) async {
    final started = await ref
        .read(assistantHostAdapterProvider)
        .speakAloud(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          started
              ? 'Reading message aloud'
              : 'Read aloud is unavailable on this device.',
        ),
      ),
    );
  }

  Future<void> _confirmClearConversation() => _clearConversation(confirm: true);

  Future<void> _clearConversation({required bool confirm}) async {
    if (confirm) {
      final shouldClear = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear conversation?'),
          content: const Text(
            'This removes the visible chat from this device. It will not delete downloaded models or settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear chat'),
            ),
          ],
        ),
      );
      if (shouldClear != true || !mounted) return;
    }
    setState(_messages.clear);
    await _chatHistoryStore.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Conversation cleared')));
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }

    if (!ref.read(assistantRuntimeReadinessProvider).canSend) {
      return;
    }

    final safety = SafetyGuardrails.withDefaults(
      profile: ref.read(assistantHostAdapterProvider).safetyProfile,
    );
    final safetyResult = safety.checkInput(message);
    if (safetyResult.isErr) {
      setState(() {
        _messages.add(
          AgentChatMessage(
            text:
                safetyResult.getErrorOrNull()?.toString() ??
                'This request was blocked by the selected safety profile.',
            isUser: false,
          ),
        );
      });
      return;
    }

    _messageController.clear();
    _restoreComposerFocus();

    // Add user message
    setState(() {
      _messages.add(AgentChatMessage(text: message, isUser: true));
    });
    _scrollMessagesToLatest();

    final pendingCalendarEvent = _pendingCalendarEvent;
    if (pendingCalendarEvent != null && _isCalendarConfirmation(message)) {
      _pendingCalendarEvent = null;
      await _createPendingCalendarEvent(pendingCalendarEvent);
      return;
    }
    if (pendingCalendarEvent != null && _isCalendarRejection(message)) {
      _pendingCalendarEvent = null;
      setState(() {
        _messages.add(
          AgentChatMessage(
            text:
                'Okay, I will keep it as an Airo notification and will not add it to Calendar.',
            isUser: false,
          ),
        );
      });
      return;
    }

    if (_pendingCalendarPermissionPrompt != null &&
        _isCalendarPermissionAllow(message)) {
      await _allowCalendarAccess();
      return;
    }

    if (await _tryIngestFinanceMessage(message)) {
      return;
    }

    final grounded = AssistantGroundedReply.tryHandle(
      prompt: message,
      selectedModelName: _selectedModelDisplayName(),
      selectedModelId: ref.read(selectedAssistantModelIdProvider),
    );
    if (grounded != null) {
      setState(() {
        _messages.add(AgentChatMessage(text: grounded, isUser: false));
      });
      _scrollMessagesToLatest();
      return;
    }

    final intercepted = await AgentToolInterceptor(
      connectors: _connectorRegistry,
    ).handle(message);
    if (intercepted != null) {
      setState(() {
        _messages.add(
          AgentChatMessage(text: intercepted.message, isUser: false),
        );
      });
      _scrollMessagesToLatest();
      return;
    }

    final intent = IntentParser.parse(message);
    if (await _handleParsedIntent(intent)) {
      return;
    }

    final promptGate = PromptQualityGate.inspectUserTurn(
      userText: message,
      historyEmpty: _messages.where((m) => m.isUser).length <= 1,
    );
    if (promptGate.blocksInference) {
      setState(() {
        _messages.add(
          AgentChatMessage(text: promptGate.userMessage, isUser: false),
        );
      });
      _scrollMessagesToLatest();
      return;
    }

    final skillStopwatch = Stopwatch()..start();
    final skillResult = await _skillOrchestrator.run(
      message,
      pinnedPersonaId: _pinnedPersonaId,
    );
    skillStopwatch.stop();
    if (skillResult.handled) {
      _pendingCalendarEvent = skillResult.pendingCalendarEvent;
      if (skillResult.pendingCalendarPermission) {
        _pendingCalendarPermissionPrompt = message;
      }
      final metadata = _buildSkillMetadata(
        traces: skillResult.traces,
        totalDuration: skillStopwatch.elapsed,
      );
      setState(() {
        _messages.add(
          AgentChatMessage(
            text: skillResult.message,
            isUser: false,
            traces: skillResult.traces,
            metadata: metadata,
            citations: skillResult.citations,
            groundingState: skillResult.groundingState,
            safetyClass: skillResult.safetyClass,
            pendingCalendarPermission: skillResult.pendingCalendarPermission,
          ),
        );
      });
      _scrollMessagesToLatest();
      if (skillResult.shouldNavigate && mounted) {
        context.go(skillResult.route!, extra: skillResult.parameters);
      }
      return;
    }

    final selectedModelId = ref.read(selectedAssistantModelIdProvider);
    if (selectedModelId == null) {
      setState(() {
        _messages.add(
          AgentChatMessage(
            text: 'Choose a project category before starting chat.',
            isUser: false,
          ),
        );
      });
      return;
    }

    // For all other queries, use the selected AI runtime to generate response.
    setState(() {
      _messages.add(
        AgentChatMessage(text: '', isUser: false), // Placeholder for streaming
      );
      _isGenerating = true;
    });
    _scrollMessagesToLatest();

    try {
      final metadata = await _generateSelectedModelResponse(
        selectedModelId,
        message,
      );
      if (metadata != null) {
        _attachMetadataToLastAssistantMessage(metadata);
      }
    } catch (e) {
      // If AI fails, show error message
      setState(() {
        _messages[_messages.length - 1] = AgentChatMessage(
          text: 'Sorry, I encountered an error: ${e.toString()}',
          isUser: false,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      } else {
        _isGenerating = false;
      }
    }
  }

  Future<void> _createPendingCalendarEvent(
    Map<String, dynamic> calendarEvent,
  ) async {
    final result = await _connectorRegistry.execute(
      'create_calendar_event',
      calendarEvent,
    );
    final title = calendarEvent['title'] as String? ?? 'reminder';
    setState(() {
      _messages.add(
        AgentChatMessage(
          text: result.isError
              ? result.message ??
                    'I could not add "$title" to Calendar on this device yet.'
              : 'I added "$title" to your calendar.',
          isUser: false,
          traces: [
            AgentActionTrace(
              title: 'Execute action',
              detail: 'create_calendar_event',
              parameters: calendarEvent,
              success: !result.isError,
            ),
          ],
        ),
      );
    });
  }

  bool _isCalendarConfirmation(String message) {
    final lower = message.toLowerCase().trim();
    return lower == 'yes' ||
        lower == 'yeah' ||
        lower == 'yep' ||
        lower == 'sure' ||
        lower.contains('add it') ||
        lower.contains('add to calendar') ||
        lower.contains('calendar too');
  }

  bool _isCalendarRejection(String message) {
    final lower = message.toLowerCase().trim();
    return lower == 'no' ||
        lower == 'nope' ||
        lower.contains('do not') ||
        lower.contains("don't") ||
        lower.contains('skip') ||
        lower.contains('not now');
  }

  bool _isCalendarPermissionAllow(String message) {
    final lower = message.toLowerCase().trim();
    return lower == 'allow' ||
        lower.contains('allow calendar') ||
        lower.contains('grant access');
  }

  Future<void> _allowCalendarAccess() async {
    final prompt = _pendingCalendarPermissionPrompt;
    _pendingCalendarPermissionPrompt = null;
    final result = await _connectorRegistry.execute(
      'calendar_permission_status',
      const {'request': true},
    );
    if (!mounted) return;
    if (result.isError || result.data['granted'] != true) {
      setState(() {
        _messages.add(
          AgentChatMessage(
            text:
                'Calendar access is disabled. Enable it in system settings to let Airo read your calendar.',
            isUser: false,
          ),
        );
      });
      return;
    }
    if (prompt == null) {
      setState(() {
        _messages.add(
          AgentChatMessage(
            text: 'Calendar access is enabled. Ask me about your schedule.',
            isUser: false,
          ),
        );
      });
      return;
    }
    final skillStopwatch = Stopwatch()..start();
    final skillResult = await _skillOrchestrator.run(prompt);
    skillStopwatch.stop();
    if (!mounted) return;
    setState(() {
      _messages.add(
        AgentChatMessage(
          text: skillResult.message,
          isUser: false,
          traces: skillResult.traces,
          metadata: _buildSkillMetadata(
            traces: skillResult.traces,
            totalDuration: skillStopwatch.elapsed,
          ),
          citations: skillResult.citations,
          groundingState: skillResult.groundingState,
          safetyClass: skillResult.safetyClass,
        ),
      );
    });
  }

  /// Offers the message to the host's finance ingestion before treating it as
  /// a normal assistant prompt. Returns true when the host consumed it.
  Future<bool> _tryIngestFinanceMessage(String message) async {
    final AssistantFinanceIngestion? outcome;
    try {
      outcome = await ref
          .read(assistantHostAdapterProvider)
          .ingestFinanceMessage(message);
    } catch (e) {
      debugPrint('Finance message ingestion failed: $e');
      return false;
    }
    if (outcome == null) return false;
    if (!mounted) return true;

    setState(() {
      _messages.add(
        AgentChatMessage(text: outcome!.responseText, isUser: false),
      );
    });

    final undoLabel = outcome.undoLabel;
    final onUndo = outcome.onUndo;
    if (undoLabel != null && onUndo != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(undoLabel),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              final confirmation = await onUndo();
              if (confirmation == null || !mounted) return;
              setState(() {
                _messages.add(
                  AgentChatMessage(text: confirmation, isUser: false),
                );
              });
            },
          ),
        ),
      );
    }
    return true;
  }

  Future<ChatResponseMetadata?> _generateSelectedModelResponse(
    String selectedModelId,
    String message, {
    Set<String> attemptedRuntimeIds = const {},
    bool dietRetry = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    int? timeToFirstTokenMs;
    String latestChunk = '';
    final attempted = {...attemptedRuntimeIds, selectedModelId};
    final history = _chatHistoryMessages();
    final dietApplies = DietPlanPluginPrompt.applies(
      currentPrompt: message,
      history: history,
    );
    var modelPrompt = dietApplies
        ? DietPlanPluginPrompt.modelUserPrompt(
            currentPrompt: message,
            history: history,
          )
        : message;
    if (dietRetry) {
      modelPrompt =
          '$modelPrompt\n\nDo not refuse. Write the meal plan now. Honor veg '
          'and allergy constraints, write every requested day, and use '
          'different dishes each day.';
    }
    var contextBuilder = _chatContextBuilder;
    var compact = _useCompactLocalChat();
    var systemPrompt = _buildChatSystemPrompt(
      message,
      builder: contextBuilder,
      compact: compact,
    );
    final contextLimit = _selectedContextLimit();
    final estimated = TokenCounter.estimate('$systemPrompt\n$modelPrompt');
    final turn = ChatTurnReliability.plan(
      userText: message,
      historyEmpty: false,
      estimatedTokens: estimated,
      modelContextLimit: contextLimit,
      definition: dietApplies
          ? AiroPromptRegistry.dietPlan
          : _personaSession.isPinned
          ? AiroPromptRegistry.skillPersona
          : AiroPromptRegistry.chatAssistant,
      prefixCache: assistantRuntimeSupportsPrefixCache(selectedModelId)
          ? PrefixCacheCapability.supported
          : PrefixCacheCapability.unsupported,
      cacheablePrefixTokens: TokenCounter.estimate(systemPrompt),
    );
    if (turn.rebuildContext) {
      contextBuilder = contextBuilder.rebuildForBudget();
      compact = true;
      systemPrompt = _buildChatSystemPrompt(
        message,
        builder: contextBuilder,
        compact: compact,
      );
    }
    try {
      if (_shouldUseReasoning(selectedModelId)) {
        return _generateReasonedResponse(
          selectedModelId: selectedModelId,
          message: message,
          modelPrompt: modelPrompt,
          dietApplies: dietApplies,
          dietRetry: dietRetry,
          attemptedRuntimeIds: attemptedRuntimeIds,
          stopwatch: stopwatch,
        );
      }
      await for (final chunk in _assistantRuntime.generateTextStream(
        selectedModelId: selectedModelId,
        prompt: modelPrompt,
        systemPrompt: systemPrompt,
      )) {
        timeToFirstTokenMs ??= stopwatch.elapsedMilliseconds;
        latestChunk = chunk;
        _replaceStreamingMessage(chunk);
      }
      stopwatch.stop();
      if (latestChunk.trim().isEmpty) {
        _replaceStreamingMessage(
          ChatOutputVerifier.userMessageFor(OutputVerification.incomplete)!,
        );
        return null;
      }
      if (dietApplies) {
        final dietConstraints = DietPlanPluginPrompt.userConstraintLines(
          currentPrompt: message,
          history: history,
        );
        latestChunk = DietPlanPluginPrompt.trimExtraDays(
          latestChunk,
          DietPlanPluginPrompt.parseDayCount(dietConstraints.join(' ')),
        );
        if (latestChunk != _messages.last.text) {
          _replaceStreamingMessage(latestChunk);
        }
        if (!dietRetry &&
            DietPlanPluginPrompt.shouldRetryPlan(
              output: latestChunk,
              constraints: dietConstraints,
            )) {
          return _generateSelectedModelResponse(
            selectedModelId,
            message,
            attemptedRuntimeIds: attemptedRuntimeIds,
            dietRetry: true,
          );
        }
      }
      final outputResult = SafetyGuardrails.withDefaults(
        profile: ref.read(assistantHostAdapterProvider).safetyProfile,
      ).checkOutput(latestChunk);
      if (outputResult.isErr) {
        _replaceStreamingMessage(
          outputResult.getErrorOrNull()?.toString() ??
              'The response was blocked by the selected safety profile.',
        );
        return null;
      }
      final denied = ToolAuthorityGuard.denyUngroundedClaim(
        message: latestChunk,
        executedTools: const [],
      );
      if (!_completeVerifiedTurn(
        goal: message,
        output: latestChunk,
        executedTools: const [],
        denied: denied,
      )) {
        return null;
      }
      return _buildRuntimeMetadata(
        selectedModelId: selectedModelId,
        prompt: message,
        response: latestChunk,
        systemPrompt: systemPrompt,
        totalDuration: stopwatch.elapsed,
        timeToFirstTokenMs: timeToFirstTokenMs,
      );
    } on AssistantRuntimeUnavailableException catch (e) {
      stopwatch.stop();
      final autoFallback = ref
          .read(assistantHostAdapterProvider)
          .autoFallbackEnabled;
      if (autoFallback) {
        final fallback = await _assistantRuntime.resolveFallback(
          failedRuntimeId: e.runtimeId ?? selectedModelId,
          excludedRuntimeIds: attempted,
          reason: e.message,
        );
        if (fallback != null) {
          await ref
              .read(selectedAssistantModelIdProvider.notifier)
              .select(fallback.fallbackRuntimeId);
          if (mounted) {
            showAssistantFallbackNotification(context, fallback);
          }
          return _generateSelectedModelResponse(
            fallback.fallbackRuntimeId,
            message,
            attemptedRuntimeIds: attempted,
          );
        }
      }
      _replaceStreamingMessage(e.message);
      return null;
    }
  }

  Future<({LlmDeviceTier tier, LlmDeviceSignals? signals})>
  _resolveReasoningDevice() async {
    if (widget.reasoningDeviceTier != null && _reasoningSignals != null) {
      return (tier: widget.reasoningDeviceTier!, signals: _reasoningSignals);
    }
    if (_reasoningSignals != null && widget.reasoningDeviceTier == null) {
      return (tier: _reasoningTier, signals: _reasoningSignals);
    }
    try {
      final probe =
          widget.deviceSignalsProbe ??
          RealLlmDeviceSignalsProbe(availableStorageMb: () async => 4096);
      final signals = await probe.probe();
      _reasoningSignals = signals;
      _reasoningTier = const LlmDeviceTierPolicy().evaluate(signals).tier;
    } on Object {
      // Keep the last known tier. Hosts that cannot probe stay at large.
    }
    return (
      tier: widget.reasoningDeviceTier ?? _reasoningTier,
      signals: _reasoningSignals,
    );
  }

  bool _shouldUseReasoning(String selectedModelId) {
    if (widget.useOnDeviceReasoning != null) {
      return widget.useOnDeviceReasoning!();
    }
    final library = ref.read(assistantModelLibraryProvider).asData?.value;
    AssistantModelCandidate? candidate;
    if (library != null) {
      for (final item in library.candidates) {
        if (item.id == selectedModelId) {
          candidate = item;
          break;
        }
      }
    }
    final package = candidate?.package;
    return shouldUseOnDeviceReasoning(
      engineReady: _generationBridge.isEngineReady,
      selectedModelId: selectedModelId,
      isLiteRt:
          selectedModelId == litertGemmaAssistantModelId ||
          (package != null &&
              AssistantModelLibraryState.isLiteRtPackage(package)),
    );
  }

  Future<ChatResponseMetadata?> _generateReasonedResponse({
    required String selectedModelId,
    required String message,
    required String modelPrompt,
    required bool dietApplies,
    required bool dietRetry,
    required Set<String> attemptedRuntimeIds,
    required Stopwatch stopwatch,
  }) async {
    final history = _chatHistoryMessages();
    final intent = IntentParser.parse(message);
    final documents = dietApplies
        ? [
            MindReasoningContextItem(
              source: 'diet_constraints',
              text: DietPlanPluginPrompt.userConstraintLines(
                currentPrompt: message,
                history: history,
              ).join('\n'),
            ),
          ]
        : const <MindReasoningContextItem>[];
    final device = await _resolveReasoningDevice();
    final request = buildMindReasoningRequest(
      userQuery: modelPrompt,
      intent: intent,
      history: history,
      tier: device.tier,
      signals: device.signals,
      documents: documents,
      toolNames: reasoningLookupToolNames(_connectorRegistry),
    );
    final fold = ReasoningStreamFold();
    int? timeToFirstTokenMs;
    await for (final event in runReasoningToolLoop(
      request: request,
      reason: _generationBridge.reason,
      executeTool: (name, argumentsJson) => executeReasoningTool(
        registry: _connectorRegistry,
        name: name,
        argumentsJson: argumentsJson,
      ),
    )) {
      fold.add(event);
      timeToFirstTokenMs ??= stopwatch.elapsedMilliseconds;
      _applyReasoningFold(fold);
    }
    stopwatch.stop();
    var latest = fold.answer;
    if (fold.cancelled && latest.trim().isEmpty) {
      _applyReasoningFold(fold);
      return null;
    }
    if (fold.error != null && latest.trim().isEmpty) {
      _assistantRuntime.lastReliabilityDiagnostic =
          FailureClassifier.recordChatCompletion(
            executionId: selectedModelId,
            text: '',
            engineOk: false,
          );
      _applyReasoningFold(fold);
      return null;
    }
    if (latest.trim().isEmpty) {
      _assistantRuntime.lastReliabilityDiagnostic =
          FailureClassifier.recordChatCompletion(
            executionId: selectedModelId,
            text: '',
            engineOk: true,
          );
      _replaceStreamingMessage(
        ChatOutputVerifier.userMessageFor(OutputVerification.incomplete)!,
      );
      return null;
    }
    _assistantRuntime.lastReliabilityDiagnostic =
        FailureClassifier.recordChatCompletion(
          executionId: selectedModelId,
          text: latest,
          engineOk: true,
        );
    if (dietApplies) {
      final dietConstraints = DietPlanPluginPrompt.userConstraintLines(
        currentPrompt: message,
        history: history,
      );
      latest = DietPlanPluginPrompt.trimExtraDays(
        latest,
        DietPlanPluginPrompt.parseDayCount(dietConstraints.join(' ')),
      );
      fold.answer = latest;
      _applyReasoningFold(fold);
      if (!dietRetry &&
          DietPlanPluginPrompt.shouldRetryPlan(
            output: latest,
            constraints: dietConstraints,
          )) {
        return _generateSelectedModelResponse(
          selectedModelId,
          message,
          attemptedRuntimeIds: attemptedRuntimeIds,
          dietRetry: true,
        );
      }
    }
    final outputResult = SafetyGuardrails.withDefaults(
      profile: ref.read(assistantHostAdapterProvider).safetyProfile,
    ).checkOutput(latest);
    if (outputResult.isErr) {
      _replaceStreamingMessage(
        outputResult.getErrorOrNull()?.toString() ??
            'The response was blocked by the selected safety profile.',
      );
      return null;
    }
    final executedTools = [for (final call in fold.toolCalls) call.name];
    final denied = ToolAuthorityGuard.denyUngroundedClaim(
      message: latest,
      executedTools: executedTools,
    );
    if (!_completeVerifiedTurn(
      goal: message,
      output: latest,
      executedTools: executedTools,
      denied: denied,
    )) {
      return null;
    }
    return _buildRuntimeMetadata(
      selectedModelId: selectedModelId,
      prompt: message,
      response: latest,
      systemPrompt: 'reasoning-engine',
      totalDuration: stopwatch.elapsed,
      timeToFirstTokenMs: timeToFirstTokenMs,
    );
  }

  void _applyReasoningFold(ReasoningStreamFold fold) {
    if (!mounted || _messages.isEmpty) return;
    final complete = fold.level != null || fold.error != null || fold.cancelled;
    final text = fold.error != null && fold.answer.trim().isEmpty
        ? fold.error!
        : fold.cancelled && fold.answer.trim().isEmpty
        ? 'Stopped.'
        : fold.answer;
    setState(() {
      final current = _messages.last;
      _messages[_messages.length - 1] = AgentChatMessage(
        text: text,
        isUser: false,
        timestamp: current.timestamp,
        traces: current.traces,
        metadata: current.metadata,
        citations: current.citations,
        groundingState: current.groundingState,
        safetyClass: current.safetyClass,
        reasoningSteps: List<ReasoningProgressStep>.from(fold.steps),
        reasoningSummary: fold.reasoningSummary,
        reasoningLevel: fold.level,
        reasoningInProgress: !complete,
        reasoningToolCalls: [
          for (final call in fold.toolCalls)
            ChatHistoryToolCall(
              name: call.name,
              argumentsJson: call.argumentsJson,
            ),
        ],
      );
    });
    _scrollMessagesToLatest(animated: false);
  }

  bool _completeVerifiedTurn({
    required String goal,
    required String output,
    required Iterable<String> executedTools,
    String? denied,
  }) {
    final verification = ChatOutputVerifier.verify(
      output: output,
      executedTools: executedTools,
    );
    final turn = ChatTurnGoal(goal: goal).start().verify(verification);
    if (!turn.succeeded) {
      _replaceStreamingMessage(
        denied ?? ChatOutputVerifier.userMessageFor(verification)!,
      );
      return false;
    }
    return true;
  }

  void _replaceStreamingMessage(String text) {
    if (!mounted || _messages.isEmpty) return;
    setState(() {
      final current = _messages.last;
      _messages[_messages.length - 1] = AgentChatMessage(
        text: text,
        isUser: false,
        timestamp: current.timestamp,
        traces: current.traces,
        metadata: current.metadata,
        citations: current.citations,
        groundingState: current.groundingState,
        safetyClass: current.safetyClass,
        reasoningSteps: current.reasoningSteps,
        reasoningSummary: current.reasoningSummary,
        reasoningLevel: current.reasoningLevel,
        reasoningInProgress: current.reasoningInProgress,
        reasoningToolCalls: current.reasoningToolCalls,
      );
    });
    _scrollMessagesToLatest(animated: false);
  }

  void _scrollMessagesToLatest({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messageScrollController.hasClients) return;
      final target = _messageScrollController.position.maxScrollExtent;
      if (animated) {
        _messageScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _messageScrollController.jumpTo(target);
      }
    });
  }

  int _selectedContextLimit() {
    final selectedId = ref.read(selectedAssistantModelIdProvider);
    final library = ref.read(assistantModelLibraryProvider).asData?.value;
    return library?.candidateById(selectedId)?.package?.contextLength ?? 0;
  }

  bool _useCompactLocalChat() {
    final selectedId = ref.read(selectedAssistantModelIdProvider);
    final library = ref.read(assistantModelLibraryProvider).asData?.value;
    final package = library?.candidateById(selectedId)?.package;
    return isCompactLocalPackage(package);
  }

  String? _selectedModelDisplayName() {
    final selectedId = ref.read(selectedAssistantModelIdProvider);
    final library = ref.read(assistantModelLibraryProvider).asData?.value;
    return library?.candidateById(selectedId)?.name;
  }

  Future<ChatResponseMetadata> _buildRuntimeMetadata({
    required String selectedModelId,
    required String prompt,
    required String response,
    String? systemPrompt,
    required Duration totalDuration,
    required int? timeToFirstTokenMs,
  }) async {
    AssistantModelCandidate? candidate;
    try {
      final state = await ref.read(assistantModelLibraryProvider.future);
      candidate = state.candidateById(selectedModelId);
    } catch (_) {
      candidate = null;
    }

    final title = candidate?.name ?? selectedModelId;
    final runtime = candidate?.runtime ?? selectedModelId;
    final isLocal =
        candidate?.local ?? selectedModelId != geminiCloudAssistantModelId;

    final stats = _assistantRuntime.lastGenerationStats;
    final promptForEstimate = [
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty) systemPrompt,
      prompt,
    ].join('\n\n');
    final promptTokens = stats != null && stats.prefillTokens > 0
        ? stats.prefillTokens
        : null;
    final completionTokens = stats != null && stats.generatedTokens > 0
        ? stats.generatedTokens
        : null;
    final estimatedCompletion =
        completionTokens ?? TokenCounter.estimate(response);
    final generationMs = timeToFirstTokenMs == null
        ? totalDuration.inMilliseconds
        : (totalDuration.inMilliseconds - timeToFirstTokenMs).clamp(
            1,
            totalDuration.inMilliseconds,
          );
    final tokensPerSecond = stats != null && stats.tokensPerSecond > 0
        ? stats.tokensPerSecond
        : generationMs > 0 && estimatedCompletion > 0
        ? estimatedCompletion / (generationMs / 1000)
        : null;

    return buildRuntimeChatResponseMetadata(
      title: title,
      runtime: runtime,
      executionMode: isLocal ? 'Local' : 'Cloud',
      recordedAt: DateTime.now(),
      totalDurationMs: totalDuration.inMilliseconds,
      modelId: selectedModelId,
      timeToFirstTokenMs: timeToFirstTokenMs,
      prompt: promptForEstimate,
      response: response,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      tokensPerSecond: tokensPerSecond,
      systemPromptPreview: _previewForMetadata(systemPrompt),
      promptPreview: _previewForMetadata(prompt),
      responsePreview: _previewForMetadata(response),
    );
  }

  List<AssistantChatContextMessage> _chatHistoryMessages() {
    return _messages
        .where((message) => message.text.trim().isNotEmpty)
        .where((message) => !isAssistantOperationalStatus(message.text))
        .map(
          (message) => AssistantChatContextMessage(
            text: message.text,
            isUser: message.isUser,
          ),
        )
        .toList(growable: false);
  }

  String _buildChatSystemPrompt(
    String currentPrompt, {
    AssistantChatContextBuilder? builder,
    bool? compact,
  }) {
    final contextBuilder = builder ?? _chatContextBuilder;
    final useCompact = compact ?? _useCompactLocalChat();
    final history = _chatHistoryMessages();
    final session = _personaSession;
    if (session.isPinned) {
      final dietPinned = session.pinnedId == 'draft-diet-plan';
      final dietApplies =
          dietPinned &&
          DietPlanPluginPrompt.applies(
            currentPrompt: currentPrompt,
            history: history,
          );
      return contextBuilder.buildSystemPrompt(
        currentUserPrompt: dietApplies
            ? DietPlanPluginPrompt.modelUserPrompt(
                currentPrompt: currentPrompt,
                history: history,
              )
            : currentPrompt,
        compact: useCompact,
        pluginPlaybooks: session.playbooks(),
        pinnedPersonaIdentity: session.identityPreamble(),
        history: dietApplies
            ? DietPlanPluginPrompt.contextHistory(
                currentPrompt: currentPrompt,
                history: history,
              )
            : history,
      );
    }
    final dietApplies = DietPlanPluginPrompt.applies(
      currentPrompt: currentPrompt,
      history: history,
    );
    return contextBuilder.buildSystemPrompt(
      currentUserPrompt: dietApplies
          ? DietPlanPluginPrompt.modelUserPrompt(
              currentPrompt: currentPrompt,
              history: history,
            )
          : currentPrompt,
      compact: useCompact,
      pluginPlaybooks: _enabledGenerativePluginPlaybooks(
        currentPrompt: currentPrompt,
        history: history,
      ),
      history: dietApplies
          ? DietPlanPluginPrompt.contextHistory(
              currentPrompt: currentPrompt,
              history: history,
            )
          : DietPlanPluginPrompt.collapseAssistantDietDrafts(history),
    );
  }

  List<String> _enabledGenerativePluginPlaybooks({
    required String currentPrompt,
    required List<AssistantChatContextMessage> history,
  }) {
    final dietApplies = DietPlanPluginPrompt.applies(
      currentPrompt: currentPrompt,
      history: history,
    );
    return _skillRegistry
        .getEnabledSkills()
        .where(
          (skill) =>
              skill.isGenerativePlugin &&
              (!skill.isPersona || skill.id == 'draft-diet-plan'),
        )
        .where((skill) => skill.id != 'draft-diet-plan' || dietApplies)
        .map((skill) => '${skill.name}: ${skill.instructions}')
        .toList(growable: false);
  }

  String _previewForMetadata(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '';
    }
    final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= 240) {
      return normalized;
    }
    return '${normalized.substring(0, 240)}...';
  }

  ChatResponseMetadata _buildSkillMetadata({
    required List<AgentActionTrace> traces,
    required Duration totalDuration,
  }) {
    return buildSkillChatResponseMetadata(
      traces: traces,
      totalDurationMs: totalDuration.inMilliseconds,
      recordedAt: DateTime.now(),
    );
  }

  void _attachMetadataToLastAssistantMessage(ChatResponseMetadata metadata) {
    if (!mounted || _messages.isEmpty) return;
    setState(() {
      final current = _messages.last;
      _messages[_messages.length - 1] = AgentChatMessage(
        text: current.text,
        isUser: current.isUser,
        timestamp: current.timestamp,
        traces: current.traces,
        metadata: metadata,
        citations: current.citations,
        groundingState: current.groundingState,
        safetyClass: current.safetyClass,
        reasoningSteps: current.reasoningSteps,
        reasoningSummary: current.reasoningSummary,
        reasoningLevel: current.reasoningLevel,
        reasoningInProgress: current.reasoningInProgress,
        reasoningToolCalls: current.reasoningToolCalls,
      );
    });
  }

  String _metadataSummary(ChatResponseMetadata metadata) {
    final duration = _formatDuration(metadata.totalDurationMs);
    final toolCount = metadata.toolCount;
    if (toolCount != null && toolCount > 0) {
      return '$toolCount ${toolCount == 1 ? 'tool' : 'tools'} · $duration';
    }
    return '${metadata.title} · $duration';
  }

  void _showMetadataSheet(AgentChatMessage message) {
    final metadata = message.metadata;
    if (metadata == null) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final rows = <(String, String)>[
          ('Model', metadata.title),
          ('Runtime', metadata.runtime),
          ('Execution', metadata.executionMode),
          ('Total duration', _formatDuration(metadata.totalDurationMs)),
          ('Timestamp', _formatTimestamp(metadata.recordedAt)),
          if (metadata.timeToFirstTokenMs != null)
            (
              'Time to first token',
              _formatDuration(metadata.timeToFirstTokenMs!),
            ),
          if (metadata.promptTokens != null)
            ('Prompt tokens', '${metadata.promptTokens}'),
          if (metadata.completionTokens != null)
            ('Completion tokens', '${metadata.completionTokens}'),
          if (metadata.totalTokens != null)
            ('Total tokens', '${metadata.totalTokens}'),
          if (metadata.tokensPerSecond != null)
            ('Tokens per second', metadata.tokensPerSecond!.toStringAsFixed(1)),
          if (metadata.toolCount != null)
            ('Tool calls', '${metadata.toolCount}'),
          if (metadata.finishReason != null)
            ('Finish reason', metadata.finishReason!),
          if (metadata.systemPromptPreview != null &&
              metadata.systemPromptPreview!.isNotEmpty)
            ('System context', metadata.systemPromptPreview!),
          if (metadata.promptPreview != null &&
              metadata.promptPreview!.isNotEmpty)
            ('Prompt preview', metadata.promptPreview!),
          if (metadata.responsePreview != null &&
              metadata.responsePreview!.isNotEmpty)
            ('Response preview', metadata.responsePreview!),
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Response details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  for (final row in rows) ...[
                    _MetadataRow(label: row.$1, value: row.$2),
                    const SizedBox(height: 8),
                  ],
                  if (message.traces.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Action timings',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final trace in message.traces)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MetadataRow(
                          label: trace.detail,
                          value: trace.durationMs == null
                              ? (trace.success ? 'Completed' : 'Failed')
                              : _formatDuration(trace.durationMs!),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openChatCustomize() {
    final catalog = ref.read(intelligenceCatalogProvider);
    final readiness = const AiProfileResolver().resolve(
      AiProfile.generalChat,
      catalog,
      constraints: IntelligenceConstraints(
        memory: ref.read(intelligenceMemoryProvider),
      ),
      overrides: ref.read(intelligenceOverridesProvider),
    );
    showProfileCustomizeSheet(
      context: context,
      readiness: readiness,
      catalog: catalog,
    );
  }

  Future<void> _selectAssistantModel(AssistantModelCandidate candidate) async {
    await ref
        .read(selectedAssistantModelIdProvider.notifier)
        .select(candidate.id);

    if (!mounted) return;
    // Warmup status lives in the model bar. Putting it in the transcript made
    // 0.5B GGUF models continue "You selected Qwen…" instead of answering.
  }

  void _openModelManager() {
    ref.read(assistantHostAdapterProvider).openModelManager(context);
  }

  IconData _iconForSkill(String iconKey) {
    return switch (iconKey) {
      'chat' => Icons.chat_bubble_outline,
      'send' => Icons.send_outlined,
      'calendar' => Icons.calendar_month_outlined,
      'notifications' => Icons.notifications_active_outlined,
      'receipt' => Icons.receipt_long,
      'restaurant' => Icons.restaurant,
      'task' => Icons.task_alt,
      'image' => Icons.image_outlined,
      'mic' => Icons.mic_none,
      'bolt' => Icons.bolt_outlined,
      'model' => Icons.model_training,
      'sports_esports' => Icons.sports_esports,
      _ => Icons.auto_awesome,
    };
  }

  Color _colorForSkill(String key) {
    return switch (key) {
      'ai_chat' => Colors.blue,
      'agent_skills' => Colors.deepPurple,
      'calendar_today' => Colors.cyan.shade700,
      'smart_reminders' => Colors.purple.shade700,
      'split_bill' => Colors.teal,
      'diet_plan' => Colors.green,
      'routine_planner' => Colors.orange,
      'ask_image' => Colors.red,
      'mobile_actions' => Colors.indigo,
      'model_management' => Colors.blueGrey,
      'arena_games' => Colors.pink,
      _ => Colors.blue,
    };
  }

  String _promptForSkill(AgentSkillCard skill) {
    return switch (skill.key) {
      'ai_chat' => 'Help me think through a task',
      'agent_skills' => 'What can you do in Airo?',
      'calendar_today' => 'Check my schedule for today',
      'smart_reminders' =>
        'Remind me to take Minoxidil every 12 hours starting at 8am',
      'split_bill' => 'Split this ₹2400 bill with Asha, Ben and Chen',
      'diet_plan' => 'Make me a 7 day diet plan',
      'routine_planner' => 'Create a morning study routine for tomorrow',
      'ask_image' => 'Ask image about this receipt',
      'mobile_actions' => 'Open mobile actions',
      'model_management' => 'Manage offline models',
      'arena_games' => 'I am bored, start chess',
      _ => skill.description,
    };
  }

  void _showPickAssistant() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return PickAssistantSheet(
          registry: _skillRegistry,
          pinnedPersonaId: _pinnedPersonaId,
          onPinnedChanged: _pinPersona,
        );
      },
    );
  }

  void _pinPersona(String? personaId) {
    final persona = personaId == null
        ? null
        : _skillRegistry.getById(personaId);
    setState(() {
      _pinnedPersonaId = personaId;
      if (persona != null) {
        _messages.add(
          AgentChatMessage(
            text: 'Switched to ${persona.name}. ${persona.description}',
            isUser: false,
            safetyClass: persona.safetyClass == CapabilitySafetyClass.general
                ? null
                : persona.safetyClass,
          ),
        );
      } else {
        _messages.add(
          AgentChatMessage(text: 'Back to normal chat.', isUser: false),
        );
      }
    });
  }

  void _showManageSkills() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return ManageSkillsSheet(
          registry: _skillRegistry,
          onChanged: () {
            if (mounted) setState(() {});
          },
        );
      },
    );
  }

  void _handleBoredom() {
    // Add agent response asking if user wants to play games
    setState(() {
      _messages.add(
        AgentChatMessage(
          text: 'Want to play some games? I can open Chess for you!',
          isUser: false,
        ),
      );
    });

    // Show action buttons
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Play Games?'),
        content: const Text('Would you like to play Chess?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Open chess game
              context.go('/games', extra: {'game': 'chess'});
            },
            child: const Text('Yes, Play Chess!'),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  void _showQuickLookup(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book),
            SizedBox(width: 12),
            Text('Quick Lookup'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Enter a word',
            hintText: 'e.g., serendipity',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (word) {
            if (word.trim().isNotEmpty) {
              Navigator.of(context).pop();
              ref
                  .read(assistantHostAdapterProvider)
                  .showWordDefinition(context, word.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              final word = controller.text.trim();
              if (word.isNotEmpty) {
                Navigator.of(context).pop();
                ref
                    .read(assistantHostAdapterProvider)
                    .showWordDefinition(context, word);
              }
            },
            icon: const Icon(Icons.search),
            label: const Text('Look Up'),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageBody extends StatelessWidget {
  const _ChatMessageBody({
    required this.text,
    required this.color,
    required this.onCopyCode,
  });

  final String text;
  final Color color;
  final ValueChanged<String> onCopyCode;

  static final _codePattern = RegExp(r'```([^\n]*)\n([\s\S]*?)```');

  @override
  Widget build(BuildContext context) {
    final matches = _codePattern.allMatches(text).toList(growable: false);
    if (matches.isEmpty) {
      return SelectableText(text, style: TextStyle(color: color));
    }

    final children = <Widget>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        children.add(
          SelectableText(
            text.substring(cursor, match.start),
            style: TextStyle(color: color),
          ),
        );
      }
      final language = match.group(1)?.trim() ?? '';
      final code = match.group(2) ?? '';
      children.add(
        _CodeBlock(
          language: language,
          code: code,
          onCopy: () => onCopyCode(code),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      children.add(
        SelectableText(text.substring(cursor), style: TextStyle(color: color)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({
    required this.language,
    required this.code,
    required this.onCopy,
  });

  final String language;
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    language.isEmpty ? 'Code' : language,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy code',
                onPressed: onCopy,
                icon: const Icon(Icons.content_copy, size: 16),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SelectableText.rich(
              key: const Key('agent_chat_code_block'),
              TextSpan(children: _highlight(code, theme.colorScheme.onSurface)),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _highlight(String source, Color foreground) {
    final keyword = RegExp(
      r'\b(?:class|const|final|function|fun|if|else|for|while|return|import|from|async|await|var|let|def|true|false|null)\b',
    );
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in keyword.allMatches(source)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: source.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(color: Colors.lightBlue.shade300),
        ),
      );
      cursor = match.end;
    }
    if (cursor < source.length) {
      spans.add(TextSpan(text: source.substring(cursor)));
    }
    if (spans.isEmpty) {
      spans.add(
        TextSpan(
          text: source,
          style: TextStyle(color: foreground),
        ),
      );
    }
    return spans;
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

String _formatDuration(int durationMs) {
  if (durationMs < 1000) {
    return '${durationMs}ms';
  }
  return '${(durationMs / 1000).toStringAsFixed(1)}s';
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
}
