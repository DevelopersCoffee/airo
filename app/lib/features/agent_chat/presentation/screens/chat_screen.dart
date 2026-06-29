import 'dart:async';

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/dictionary/dictionary.dart';
import '../../../../core/utils/locale_settings.dart';
import '../../../agent_chat/data/connectors/calendar_connector.dart';
import '../../../agent_chat/data/connectors/date_time_connector.dart';
import '../../../agent_chat/data/connectors/notification_connector.dart';
import '../../../agent_chat/data/connectors/route_connector.dart';
import '../../../agent_chat/data/services/assistant_chat_context_builder.dart';
import '../../../agent_chat/data/services/assistant_runtime_service.dart';
import '../../../agent_chat/data/services/selected_runtime_agent_skill_model_client.dart';
import '../../../agent_chat/application/assistant_model_preferences.dart';
import '../../../agent_chat/domain/models/agent_skill.dart';
import '../../../agent_chat/domain/models/assistant_runtime_ids.dart';
import '../../../agent_chat/domain/models/chat_response_metadata.dart';
import '../../../agent_chat/domain/services/agent_connector_registry.dart';
import '../../../agent_chat/domain/services/agent_skill_orchestrator.dart';
import '../../../agent_chat/domain/services/agent_skill_registry.dart';
import '../../../agent_chat/domain/services/intent_parser.dart';
import '../../../agent_chat/domain/services/tool_registry.dart';
import '../../../agent_chat/presentation/widgets/fallback_notification.dart';
import '../../../agent_chat/presentation/widgets/manage_skills_sheet.dart';
import '../../../agent_chat/presentation/widgets/skill_action_trace_card.dart';
import '../../../coins/application/providers/dashboard_providers.dart';
import '../../../coins/application/providers/expense_providers.dart';
import '../../../coins/application/services/finance_chat_ingestion_service.dart';
import '../../../settings/application/ai_preferences_settings.dart';
import '../../../../core/services/gemini_nano_service.dart';
import '../../../../core/services/litert_lm_service.dart';
import '../../../../core/services/local_runtime_preloader_service.dart';
import 'model_library_screen.dart';

/// Chat message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<AgentActionTrace> traces;
  final ChatResponseMetadata? metadata;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.traces = const [],
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();
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
  });

  final AssistantRuntimeService? assistantRuntimeService;
  final LocalRuntimePreloaderService? localRuntimePreloader;
  final AgentSkillOrchestrator? skillOrchestrator;
  final bool enableAiInitialization;
  final List<ChatMessage>? initialMessages;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late TextEditingController _messageController;
  final List<ChatMessage> _messages = [];
  final ToolRegistry _toolRegistry = ToolRegistry();
  AgentSkillRegistry _skillRegistry = AgentSkillRegistry();
  final AgentConnectorRegistry _connectorRegistry = AgentConnectorRegistry(
    connectors: [
      DateTimeConnector(),
      NativeCalendarPermissionConnector(),
      NativeCalendarConnector(),
      NativeCreateCalendarEventConnector(),
      ScheduleNotificationConnector(),
      RouteConnector(),
    ],
  );
  final GeminiNanoService _geminiNano = GeminiNanoService();
  final LiteRtLmService _liteRtLm = LiteRtLmService();
  late final AssistantRuntimeService _assistantRuntime;
  late final LocalRuntimePreloaderService _localRuntimePreloader;
  late AgentSkillOrchestrator _skillOrchestrator;
  final AssistantChatContextBuilder _chatContextBuilder =
      const AssistantChatContextBuilder();
  Map<String, dynamic>? _pendingCalendarEvent;
  bool _isDeviceSupported = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _assistantRuntime =
        widget.assistantRuntimeService ??
        AssistantRuntimeService(geminiNano: _geminiNano, liteRtLm: _liteRtLm);
    _localRuntimePreloader =
        widget.localRuntimePreloader ??
        LocalRuntimePreloaderService(
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
            ChatMessage(
              text:
                  'Hi! I can chat, use enabled skills, check your schedule, split bills, draft diet plans, plan routines, and open Airo tools from here.',
              isUser: false,
            ),
          ],
    );
    if (widget.enableAiInitialization) {
      _initializeAI();
    }
  }

  AgentSkillOrchestrator _buildSkillOrchestrator(AgentSkillRegistry registry) {
    return AgentSkillOrchestrator(
      skillRegistry: registry,
      connectorRegistry: _connectorRegistry,
      modelClient: SelectedRuntimeAgentSkillModelClient(
        runtimeService: _assistantRuntime,
        selectedModelId: () => ref.read(selectedAssistantModelIdProvider),
      ),
      useFallbackModelClient: false,
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
    _localRuntimePreloader.abortPreload();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedAssistantModelId = ref.watch(
      selectedAssistantModelIdProvider,
    );

    if (selectedAssistantModelId == null) {
      return ModelLibraryScreen(
        onModelSelected: _selectAssistantModel,
        onOpenModelManager: _openModelManager,
      );
    }

    // No AppBar here - global AppBar is in AppShell
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DictionarySelectionArea(
        child: Column(
          children: [
            _buildSelectedModelBar(selectedAssistantModelId),

            // Messages list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount:
                    _messages.length + (_shouldShowPromptSuggestions ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _buildSamplePrompts();
                  }

                  final message = _messages[index];
                  return _buildMessage(message);
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
                    onPressed: _showManageSkills,
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('Skills'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('agent_chat_input'),
                      controller: _messageController,
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
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('agent_chat_send_button'),
                    onPressed: _sendMessage,
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

  bool get _shouldShowPromptSuggestions {
    return !_messages.any((message) => message.isUser);
  }

  Widget _buildSelectedModelBar(String selectedModelId) {
    final library = ref.watch(assistantModelLibraryProvider);

    return library.maybeWhen(
      data: (state) {
        final candidate = state.candidateById(selectedModelId);
        final label = candidate?.name ?? 'Selected model';
        final runtime = candidate?.runtime ?? selectedModelId;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                candidate?.local == false
                    ? Icons.cloud_outlined
                    : Icons.memory_outlined,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      runtime,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Change model',
                onPressed: () {
                  ref
                      .read(selectedAssistantModelIdProvider.notifier)
                      .select(null);
                },
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.swap_horiz, size: 20),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildSamplePrompts() {
    final prompts = _toolRegistry.getSkillCards();
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
                  _messageController.selection = TextSelection.collapsed(
                    offset: _messageController.text.length,
                  );
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

    final toolResult = await _toolRegistry.executeIntent(intent);
    if (toolResult.isError) {
      return false;
    }

    setState(() {
      _messages.add(ChatMessage(text: toolResult.message, isUser: false));
    });

    if (toolResult.shouldNavigate && mounted) {
      context.go(toolResult.route!, extra: toolResult.parameters);
    }
    return true;
  }

  Widget _buildMessage(ChatMessage message) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxWidth =
        MediaQuery.of(context).size.width *
        (message.traces.isNotEmpty || message.metadata != null ? 0.86 : 0.75);

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (message.traces.isNotEmpty)
              SkillActionTraceCard(traces: message.traces),
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
              child: Text(
                message.text,
                style: TextStyle(
                  color: colorScheme.primary.withValues(alpha: 0.9),
                ),
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
          ],
        ),
      ),
    );
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }

    _messageController.clear();

    // Add user message
    setState(() {
      _messages.add(ChatMessage(text: message, isUser: true));
    });

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
          ChatMessage(
            text:
                'Okay, I will keep it as an Airo notification and will not add it to Calendar.',
            isUser: false,
          ),
        );
      });
      return;
    }

    if (await _tryIngestFinanceMessage(message)) {
      return;
    }

    final intent = IntentParser.parse(message);
    if (await _handleParsedIntent(intent)) {
      return;
    }

    final skillStopwatch = Stopwatch()..start();
    final skillResult = await _skillOrchestrator.run(message);
    skillStopwatch.stop();
    if (skillResult.handled) {
      _pendingCalendarEvent = skillResult.pendingCalendarEvent;
      final metadata = _buildSkillMetadata(
        traces: skillResult.traces,
        totalDuration: skillStopwatch.elapsed,
      );
      setState(() {
        _messages.add(
          ChatMessage(
            text: skillResult.message,
            isUser: false,
            traces: skillResult.traces,
            metadata: metadata,
          ),
        );
      });
      if (skillResult.shouldNavigate && mounted) {
        context.go(skillResult.route!, extra: skillResult.parameters);
      }
      return;
    }

    final selectedModelId = ref.read(selectedAssistantModelIdProvider);
    if (selectedModelId == null) {
      setState(() {
        _messages.add(
          ChatMessage(
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
        ChatMessage(text: '', isUser: false), // Placeholder for streaming
      );
      _isGenerating = true;
    });

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
        _messages[_messages.length - 1] = ChatMessage(
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
        ChatMessage(
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

  Future<bool> _tryIngestFinanceMessage(String message) async {
    try {
      final accounts = await ref.read(expenseAccountOptionsProvider.future);
      final defaultAccount = accounts
          .where((account) => account.isDefault)
          .fold(accounts.first, (selected, account) => account);
      final accountId = defaultAccount.id;

      final result = await ref
          .read(financeChatIngestionServiceProvider)
          .ingest(message, accountId: accountId);

      if (result.status == FinanceChatIngestionStatus.ignored) {
        return false;
      }

      if (result.changedLedger) {
        _refreshCoinsProviders();
      }

      if (!mounted) return true;
      final response = _financeIngestionResponse(result);
      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
      });
      _showFinanceIngestionUndo(result);
      return true;
    } catch (e) {
      debugPrint('Finance SMS ingestion failed: $e');
      return false;
    }
  }

  void _refreshCoinsProviders() {
    ref.invalidate(allExpensesProvider);
    ref.invalidate(recentExpensesProvider);
    ref.invalidate(spentTodayProvider);
    ref.invalidate(spentThisMonthProvider);
    ref.invalidate(monthlySpendingByCategoryProvider);
    ref.invalidate(dashboardDataProvider);
  }

  void _showFinanceIngestionUndo(FinanceChatIngestionResult result) {
    final transaction = result.transaction;
    if (transaction == null ||
        (result.status != FinanceChatIngestionStatus.created &&
            result.status != FinanceChatIngestionStatus.needsReview) ||
        !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${transaction.description} to Coins.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final deleteResult = await ref
                .read(transactionRepositoryProvider)
                .delete(transaction.id);
            if (deleteResult.error != null || !mounted) {
              return;
            }
            _refreshCoinsProviders();
            setState(() {
              _messages.add(
                ChatMessage(
                  text: 'Removed ${transaction.description} from Coins.',
                  isUser: false,
                ),
              );
            });
          },
        ),
      ),
    );
  }

  String _financeIngestionResponse(FinanceChatIngestionResult result) {
    final formatter = ref.read(currencyFormatterProvider);
    final parsed = result.parsed;
    if (parsed == null) {
      return 'I could not read this as a finance transaction.';
    }

    final amount = formatter.formatCents(parsed.amountCents);
    switch (result.status) {
      case FinanceChatIngestionStatus.created:
        return 'Added to Coins: ${parsed.description} - $amount - ${parsed.categoryId}.';
      case FinanceChatIngestionStatus.updated:
        return 'Updated Coins: ${parsed.description} - $amount - ${parsed.categoryId}.';
      case FinanceChatIngestionStatus.needsReview:
        if (result.transaction != null) {
          return 'Queued for Coins review: ${parsed.description} - $amount - ${parsed.categoryId}.';
        }
        return 'I found a possible transaction for ${parsed.description} - $amount, but it needs review before I add it.';
      case FinanceChatIngestionStatus.failed:
        return result.message ?? 'I could not update Coins from this message.';
      case FinanceChatIngestionStatus.ignored:
        return 'I could not read this as a finance transaction.';
    }
  }

  Future<ChatResponseMetadata?> _generateSelectedModelResponse(
    String selectedModelId,
    String message, {
    Set<String> attemptedRuntimeIds = const {},
  }) async {
    final stopwatch = Stopwatch()..start();
    int? timeToFirstTokenMs;
    String latestChunk = '';
    final attempted = {...attemptedRuntimeIds, selectedModelId};
    final systemPrompt = _buildChatSystemPrompt(message);
    try {
      await for (final chunk in _assistantRuntime.generateTextStream(
        selectedModelId: selectedModelId,
        prompt: message,
        systemPrompt: systemPrompt,
      )) {
        timeToFirstTokenMs ??= stopwatch.elapsedMilliseconds;
        latestChunk = chunk;
        _replaceStreamingMessage(chunk);
      }
      stopwatch.stop();
      if (latestChunk.trim().isEmpty) {
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
      final autoFallback = ref.read(aiPreferencesSettingsProvider).autoFallback;
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

  void _replaceStreamingMessage(String text) {
    if (!mounted || _messages.isEmpty) return;
    setState(() {
      final current = _messages.last;
      _messages[_messages.length - 1] = ChatMessage(
        text: text,
        isUser: false,
        timestamp: current.timestamp,
        traces: current.traces,
        metadata: current.metadata,
      );
    });
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

    return buildRuntimeChatResponseMetadata(
      title: title,
      runtime: runtime,
      executionMode: isLocal ? 'Local' : 'Cloud',
      recordedAt: DateTime.now(),
      totalDurationMs: totalDuration.inMilliseconds,
      modelId: selectedModelId,
      timeToFirstTokenMs: timeToFirstTokenMs,
      prompt: prompt,
      response: response,
      systemPromptPreview: _previewForMetadata(systemPrompt),
      promptPreview: _previewForMetadata(prompt),
      responsePreview: _previewForMetadata(response),
    );
  }

  String _buildChatSystemPrompt(String currentPrompt) {
    return _chatContextBuilder.buildSystemPrompt(
      currentUserPrompt: currentPrompt,
      history: _messages
          .where((message) => message.text.trim().isNotEmpty)
          .map(
            (message) => AssistantChatContextMessage(
              text: message.text,
              isUser: message.isUser,
            ),
          )
          .toList(growable: false),
    );
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
      _messages[_messages.length - 1] = ChatMessage(
        text: current.text,
        isUser: current.isUser,
        timestamp: current.timestamp,
        traces: current.traces,
        metadata: metadata,
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

  void _showMetadataSheet(ChatMessage message) {
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
        );
      },
    );
  }

  Future<void> _selectAssistantModel(AssistantModelCandidate candidate) async {
    await ref
        .read(selectedAssistantModelIdProvider.notifier)
        .select(candidate.id);

    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(
          text:
              'Project ready. I picked ${candidate.name} for this category. ${candidate.local ? 'It runs on this device when available.' : 'This category uses the configured cloud fallback.'}',
          isUser: false,
        ),
      );
    });
  }

  void _openModelManager() {
    context.push('/agent/profile');
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
      'diet_plan' => 'Make me a 7 day vegetarian diet plan',
      'routine_planner' => 'Create a morning study routine for tomorrow',
      'ask_image' => 'Ask image about this receipt',
      'mobile_actions' => 'Open mobile actions',
      'model_management' => 'Manage offline models',
      'arena_games' => 'I am bored, start chess',
      _ => skill.description,
    };
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
        ChatMessage(
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
              DictionaryPopup.showAdaptive(context, word.trim());
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
                DictionaryPopup.showAdaptive(context, word);
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
