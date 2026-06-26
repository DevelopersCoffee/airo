import 'dart:async';

import 'package:flutter/material.dart' hide Intent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/dictionary/dictionary.dart';
import '../../../agent_chat/data/connectors/calendar_connector.dart';
import '../../../agent_chat/data/connectors/date_time_connector.dart';
import '../../../agent_chat/data/connectors/notification_connector.dart';
import '../../../agent_chat/data/connectors/route_connector.dart';
import '../../../agent_chat/data/services/gemini_agent_skill_model_client.dart';
import '../../../agent_chat/domain/models/agent_skill.dart';
import '../../../agent_chat/domain/services/agent_connector_registry.dart';
import '../../../agent_chat/domain/services/agent_skill_orchestrator.dart';
import '../../../agent_chat/domain/services/agent_skill_registry.dart';
import '../../../agent_chat/domain/services/intent_parser.dart';
import '../../../agent_chat/domain/services/tool_registry.dart';
import '../../../agent_chat/presentation/widgets/manage_skills_sheet.dart';
import '../../../agent_chat/presentation/widgets/skill_action_trace_card.dart';
import '../../../../core/services/gemini_api_service.dart';
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
  late final AgentConnectorRegistry _connectorRegistry;
  late final AgentSkillOrchestrator _skillOrchestrator;
  Map<String, dynamic>? _pendingCalendarEvent;
  bool _isDeviceSupported = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _connectorRegistry = AgentConnectorRegistry(
      connectors: [
        DateTimeConnector(),
        NativeCalendarConnector(),
        NativeCreateCalendarEventConnector(),
        ScheduleNotificationConnector(),
        RouteConnector(),
      ],
    );
    _skillOrchestrator = AgentSkillOrchestrator(
      skillRegistry: _skillRegistry,
      connectorRegistry: _connectorRegistry,
      modelClient: GeminiAgentSkillModelClient(_geminiNano),
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
        if (initialized) {
          unawaited(
            _geminiNano.warmup().then((warmed) {
              debugPrint('Gemini Nano warmup completed: $warmed');
            }),
          );
        }
      }

      unawaited(
        _liteRtLm.warmupInstalledModel().then((warmed) {
          debugPrint('LiteRT-LM warmup completed: $warmed');
        }),
      );

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
    return Scaffold(
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
                border: Border(
                  top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
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
                          borderRadius: BorderRadius.circular(24),
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
                  FloatingActionButton(
                    key: const Key('agent_chat_send_button'),
                    mini: true,
                    onPressed: _sendMessage,
                    child: const Icon(Icons.send),
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
                  if (prompt.route != null && prompt.key == 'live_notes') {
                    context.go(prompt.route!);
                    return;
                  }
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
                color: message.isUser ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black,
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

    final intent = IntentParser.parse(message);
    if (await _handleParsedIntent(intent)) {
      return;
    }

    final skillResult = await _skillOrchestrator.run(message);
    if (skillResult.handled) {
      _pendingCalendarEvent = skillResult.pendingCalendarEvent;
      setState(() {
        _messages.add(
          ChatMessage(
            text: skillResult.message,
            isUser: false,
            traces: skillResult.traces,
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

  Future<void> _generateSelectedModelResponse(
    String selectedModelId,
    String message,
  ) async {
    switch (selectedModelId) {
      case geminiNanoAssistantModelId:
        if (!_isDeviceSupported && !await _geminiNano.isSupported()) {
          _replaceStreamingMessage(
            'Gemini Nano is not available on this device. Open Project setup and choose another category.',
          );
          return;
        }
        if (!_geminiNano.isInitialized) {
          final initialized = await _geminiNano.initialize();
          if (!initialized) {
            _replaceStreamingMessage(
              'Gemini Nano did not initialize on this device. Open Project setup and choose another category.',
            );
            return;
          }
        }
        await for (final chunk in _geminiNano.generateContentStream(message)) {
          _replaceStreamingMessage(chunk);
        }
        return;

      case litertGemmaAssistantModelId:
        final response = await _liteRtLm.generateText(message);
        _replaceStreamingMessage(
          response ??
              'LiteRT-LM is not configured. Install a local model or set LITERT_LM_MODEL_PATH/LITERT_LM_MODEL_URL.',
        );
        return;

      case geminiCloudAssistantModelId:
        await geminiApiService.initialize();
        if (!geminiApiService.isAvailable) {
          _replaceStreamingMessage(
            'Gemini Cloud is not configured. Launch with --dart-define=GEMINI_API_KEY=... to use this real API path.',
          );
          return;
        }
        final response = await geminiApiService.generateText(message);
        _replaceStreamingMessage(response ?? 'Gemini Cloud returned no text.');
        return;

      default:
        _replaceStreamingMessage(
          'This package is downloaded, but chat inference is not wired to it yet. Use Gemini Nano or the Gemma mobile package, or manage packages in Profile.',
        );
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
      'live_notes' => Colors.green.shade700,
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
      'live_notes' => 'Start live notes',
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
