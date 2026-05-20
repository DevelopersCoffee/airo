import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/dictionary/dictionary.dart';
import '../../../agent_chat/domain/services/intent_parser.dart';
import '../../../agent_chat/domain/services/tool_registry.dart';
import '../../../quotes/presentation/widgets/daily_quote_card.dart';
import '../../../../core/services/gemini_nano_service.dart';

/// Chat message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
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
  final GeminiNanoService _geminiNano = GeminiNanoService();
  bool _isDeviceSupported = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    // Add welcome message
    _messages.add(
      ChatMessage(
        text: 'Hi! I\'m your AI assistant. How can I help you today?',
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
                        : 'Cloud AI Mode',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _isDeviceSupported
                        ? 'On-device AI ready • Fast & Private'
                        : 'On-device AI not available',
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
                  return Align(
                    alignment: message.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: message.isUser
                            ? colorScheme.primary.withValues(alpha: 0.16)
                            : colorScheme.surface.withValues(alpha: 0.72),
                        border: Border.all(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: colorScheme.primary.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  );
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
                  Expanded(
                    child: TextField(
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

  Widget _buildSamplePrompts() {
    final prompts = [
      {
        'icon': Icons.summarize,
        'title': 'Summarize',
        'description': 'Summarize the key points from this document',
        'color': Colors.blue,
      },
      {
        'icon': Icons.image,
        'title': 'Describe Image',
        'description': 'Describe what you see in this image in detail',
        'color': Colors.purple,
      },
      {
        'icon': Icons.edit,
        'title': 'Writing Help',
        'description': 'Help me improve and rewrite this text professionally',
        'color': Colors.orange,
      },
      {
        'icon': Icons.restaurant,
        'title': 'Diet Plan',
        'description':
            'Create a 7-day healthy diet plan based on my preferences',
        'color': Colors.green,
      },
      {
        'icon': Icons.receipt,
        'title': 'Split Bill',
        'description': 'Help me split this bill equally among friends',
        'color': Colors.teal,
      },
      {
        'icon': Icons.description,
        'title': 'Fill Form',
        'description': 'Extract information from this document to fill a form',
        'color': Colors.indigo,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'WORKFLOWS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.62),
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
                return _WorkflowPromptTile(
                  icon: prompt['icon'] as IconData,
                  title: prompt['title'] as String,
                  description: prompt['description'] as String,
                  onTap: () {
                    _messageController.text = prompt['description'] as String;
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: 24),
      ],
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

    // Parse intent first to check for navigation commands
    final intent = IntentParser.parse(message);

    // Handle boredom intent
    if (intent.type == IntentType.boredom) {
      _handleBoredom();
      return;
    }

    // Handle navigation intents (play music, open games, etc.)
    if (intent.type != IntentType.unknown) {
      final navTarget = await _toolRegistry.handleIntent(intent);

      if (navTarget != null && navTarget.route != '/agent') {
        // Add agent response
        setState(() {
          _messages.add(
            ChatMessage(text: navTarget.message ?? 'Done!', isUser: false),
          );
        });

        // Navigate to target
        if (mounted) {
          context.go(navTarget.route);
        }
        return;
      }
    }

    // For all other queries, use AI to generate response
    setState(() {
      _messages.add(
        ChatMessage(text: '', isUser: false), // Placeholder for streaming
      );
    });

    try {
      String fullResponse = '';

      // Use streaming response from Gemini Nano
      await for (final chunk in _geminiNano.generateContentStream(message)) {
        fullResponse = chunk;
        setState(() {
          _messages[_messages.length - 1] = ChatMessage(
            text: fullResponse,
            isUser: false,
          );
        });
      }
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

class _WorkflowPromptTile extends StatelessWidget {
  const _WorkflowPromptTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.3),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary.withValues(alpha: 0.62),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
