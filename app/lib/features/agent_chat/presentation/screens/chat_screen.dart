import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/dictionary/dictionary.dart';
import '../../../../core/utils/locale_settings.dart';
import '../../../agent_chat/data/connectors/calendar_connector.dart';
import '../../../agent_chat/data/connectors/date_time_connector.dart';
import '../../../agent_chat/data/connectors/notification_connector.dart';
import '../../../agent_chat/data/services/assistant_runtime_service.dart';
import '../../../agent_chat/data/services/selected_runtime_agent_skill_model_client.dart';
import '../../../agent_chat/domain/models/agent_skill.dart';
import '../../../agent_chat/domain/models/assistant_runtime_ids.dart';
import '../../../agent_chat/domain/services/agent_connector_registry.dart';
import '../../../agent_chat/domain/services/agent_skill_orchestrator.dart';
import '../../../agent_chat/domain/services/agent_skill_registry.dart';
import '../../../agent_chat/domain/services/intent_parser.dart';
import '../../../agent_chat/domain/services/tool_registry.dart';
import '../../../agent_chat/presentation/widgets/manage_skills_sheet.dart';
import '../../../agent_chat/presentation/widgets/skill_action_trace_card.dart';
import '../../../coins/application/providers/dashboard_providers.dart';
import '../../../coins/application/providers/expense_providers.dart';
import '../../../coins/application/services/finance_chat_ingestion_service.dart';
import '../../../quotes/presentation/widgets/daily_quote_card.dart';
import '../../../settings/presentation/screens/ai_models_screen.dart';
import '../../../../core/services/gemini_nano_service.dart';
import '../../../../core/services/litert_lm_service.dart';
import 'model_library_screen.dart';

/// Chat message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<AgentActionTrace> traces;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.traces = const [],
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Agent chat screen
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late TextEditingController _messageController;
  final List<ChatMessage> _messages = [];
  final ToolRegistry _toolRegistry = ToolRegistry();
  final AgentSkillRegistry _skillRegistry = AgentSkillRegistry();
  final GeminiNanoService _geminiNano = GeminiNanoService();
  final LiteRtLmService _liteRtLm = LiteRtLmService();
  late final AssistantRuntimeService _assistantRuntime;
  late final AgentSkillOrchestrator _skillOrchestrator;
  bool _isDeviceSupported = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _assistantRuntime = AssistantRuntimeService(
      geminiNano: _geminiNano,
      liteRtLm: _liteRtLm,
    );
    _skillOrchestrator = AgentSkillOrchestrator(
      skillRegistry: _skillRegistry,
      connectorRegistry: AgentConnectorRegistry(
        connectors: [
          DateTimeConnector(),
          NativeCalendarConnector(),
          ScheduleNotificationConnector(),
        ],
      ),
      modelClient: SelectedRuntimeAgentSkillModelClient(
        runtimeService: _assistantRuntime,
        selectedModelId: () => ref.read(selectedAssistantModelIdProvider),
      ),
      useFallbackModelClient: false,
    );
    // Add welcome message
    _messages.add(
      ChatMessage(
        text:
            'Hi! I can chat, use enabled skills, check your schedule, split bills, draft diet plans, plan routines, and open Airo tools from here.',
        isUser: false,
      ),
    );
    _initializeAI();
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

      // Initialize Gemini Nano if supported
      if (isSupported) {
        final initialized = await _geminiNano.initialize();
        debugPrint('Gemini Nano initialized: $initialized');
      }

      // Show bottom banner popup
      if (mounted) {
        _showBottomBanner();
      }
    } catch (e) {
      debugPrint('Error initializing AI: $e');
    }
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
            // Daily quote card
            const DailyQuoteCard(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              elevation: 1,
            ),
            _buildSelectedModelBar(selectedAssistantModelId),

            // Messages list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + 1, // +1 for sample prompts
                itemBuilder: (context, index) {
                  // Show sample prompts at the end
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

  Widget _buildSelectedModelBar(String selectedModelId) {
    final library = ref.watch(assistantModelLibraryProvider);

    return library.maybeWhen(
      data: (state) {
        final candidate = state.candidateById(selectedModelId);
        final label = candidate?.name ?? 'Selected model';
        final runtime = candidate?.runtime ?? selectedModelId;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                child: Text(
                  '$label - $runtime',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () {
                  ref
                      .read(selectedAssistantModelIdProvider.notifier)
                      .select(null);
                },
                child: const Text('Change'),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Try these prompts:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                childAspectRatio: constraints.maxWidth < 420 ? 1.55 : 2.35,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: prompts.length,
              itemBuilder: (context, index) {
                final prompt = prompts[index];
                final color = _colorForSkill(prompt.key);

                return InkWell(
                  onTap: () {
                    _messageController.text = _promptForSkill(prompt);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.1),
                          color.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: color.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _iconForSkill(prompt.iconKey),
                          size: 28,
                          color: color,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          prompt.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prompt.description,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxWidth =
        MediaQuery.of(context).size.width *
        (message.traces.isNotEmpty ? 0.86 : 0.75);

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
          ],
        ),
      ),
    );
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();

    // Add user message
    setState(() {
      _messages.add(ChatMessage(text: message, isUser: true));
    });

    if (await _tryIngestFinanceMessage(message)) {
      return;
    }

    final skillResult = await _skillOrchestrator.run(message);
    if (skillResult.handled) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: skillResult.message,
            isUser: false,
            traces: skillResult.traces,
          ),
        );
      });
      return;
    }

    // Parse intent first to check for navigation commands
    final intent = IntentParser.parse(message);

    // Handle boredom intent
    if (intent.type == IntentType.boredom) {
      _handleBoredom();
      return;
    }

    // Handle navigation intents (play music, open games, etc.)
    if (intent.type != IntentType.unknown) {
      final toolResult = await _toolRegistry.executeIntent(intent);

      if (!toolResult.isError) {
        setState(() {
          _messages.add(ChatMessage(text: toolResult.message, isUser: false));
        });

        if (toolResult.shouldNavigate && mounted) {
          context.go(toolResult.route!, extra: toolResult.parameters);
        }
        return;
      }
    }

    final selectedModelId = ref.read(selectedAssistantModelIdProvider);
    if (selectedModelId == null) {
      setState(() {
        _messages.add(
          ChatMessage(text: noAssistantModelSelectedMessage, isUser: false),
        );
      });
      return;
    }

    // For all other queries, use the selected AI runtime to generate response.
    setState(() {
      _messages.add(
        ChatMessage(text: '', isUser: false), // Placeholder for streaming
      );
    });

    try {
      await _generateSelectedModelResponse(selectedModelId, message);
    } catch (e) {
      // If AI fails, show error message
      setState(() {
        _messages[_messages.length - 1] = ChatMessage(
          text: 'Sorry, I encountered an error: ${e.toString()}',
          isUser: false,
        );
      });
    }
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
        return 'I found a possible transaction for ${parsed.description} - $amount, but it needs review before I add it.';
      case FinanceChatIngestionStatus.failed:
        return result.message ?? 'I could not update Coins from this message.';
      case FinanceChatIngestionStatus.ignored:
        return 'I could not read this as a finance transaction.';
    }
  }

  Future<void> _generateSelectedModelResponse(
    String selectedModelId,
    String message,
  ) async {
    try {
      await for (final chunk in _assistantRuntime.generateTextStream(
        selectedModelId: selectedModelId,
        prompt: message,
      )) {
        _replaceStreamingMessage(chunk);
      }
    } on AssistantRuntimeUnavailableException catch (e) {
      _replaceStreamingMessage(e.message);
    }
  }

  void _replaceStreamingMessage(String text) {
    if (!mounted || _messages.isEmpty) return;
    setState(() {
      _messages[_messages.length - 1] = ChatMessage(text: text, isUser: false);
    });
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
              'Using ${candidate.name}. Runtime: ${candidate.runtime}. ${candidate.local ? 'This is an on-device path.' : 'This sends prompts to the configured API.'}',
          isUser: false,
        ),
      );
    });
  }

  void _openModelManager() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AIModelsScreen()));
  }

  IconData _iconForSkill(String iconKey) {
    return switch (iconKey) {
      'chat' => Icons.chat_bubble_outline,
      'send' => Icons.send_outlined,
      'calendar' => Icons.calendar_month_outlined,
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
      'split_bill' => Colors.teal,
      'diet_plan' => Colors.green,
      'routine_planner' => Colors.orange,
      'ask_image' => Colors.red,
      'audio_scribe' => Colors.green.shade700,
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
      'split_bill' => 'Split this ₹2400 bill with Asha, Ben and Chen',
      'diet_plan' => 'Make me a 7 day vegetarian diet plan',
      'routine_planner' => 'Create a morning study routine for tomorrow',
      'ask_image' => 'Ask image about this receipt',
      'audio_scribe' => 'Audio scribe this recording',
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
