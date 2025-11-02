import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../agent_chat/domain/services/intent_parser.dart';
import '../../../agent_chat/domain/services/tool_registry.dart';

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
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Chat'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Show menu
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
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
                      color: message.isUser ? Colors.blue : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : Colors.black,
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
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
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
                  mini: true,
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
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

    // Parse intent
    final intent = IntentParser.parse(message);

    // Handle boredom intent
    if (intent.type == IntentType.boredom) {
      _handleBoredom();
      return;
    }

    // Handle other intents
    final navTarget = await _toolRegistry.handleIntent(intent);

    if (navTarget != null) {
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
    } else {
      // Add error message
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'Sorry, I didn\'t understand that. Try "play music", "open games", or "play chess".',
            isUser: false,
          ),
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
}
