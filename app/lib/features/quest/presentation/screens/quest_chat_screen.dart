import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../quest/domain/models/quest_models.dart';
import '../../../quest/application/providers/quest_provider.dart';
import '../widgets/reminder_dialog.dart';
import '../widgets/attachment_button.dart';
import '../../../../core/ai/widgets/ai_provider_selector.dart';
import '../../../../core/ai/ai_router_service.dart';
import '../../../../core/ai/ai_provider.dart';
import '../../../../core/services/gemini_nano_service.dart';

/// Quest chat screen - interact with AI about uploaded files
class QuestChatScreen extends ConsumerStatefulWidget {
  final String questId;

  const QuestChatScreen({super.key, required this.questId});

  @override
  ConsumerState<QuestChatScreen> createState() => _QuestChatScreenState();
}

class _QuestChatScreenState extends ConsumerState<QuestChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  final List<Map<String, String>> _attachedFiles = [];
  final GeminiNanoService _geminiNano = GeminiNanoService();
  bool _isDeviceSupported = false;

  @override
  void initState() {
    super.initState();
    _checkDeviceSupport();
  }

  Future<void> _checkDeviceSupport() async {
    try {
      final isSupported = await _geminiNano.isSupported();
      if (mounted) {
        setState(() {
          _isDeviceSupported = isSupported;
        });

        // Show bottom banner popup
        _showBottomBanner();
      }
    } catch (e) {
      debugPrint('Error checking device support: $e');
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
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    setState(() => _isLoading = true);

    try {
      await ref.read(processQueryProvider((widget.questId, message)).future);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  IconData _getProviderIcon(AIProvider provider) {
    switch (provider) {
      case AIProvider.nano:
        return Icons.phone_android;
      case AIProvider.cloud:
        return Icons.cloud;
      case AIProvider.auto:
        return Icons.auto_awesome;
      case AIProvider.gguf:
      case AIProvider.gemma:
      case AIProvider.phi:
      case AIProvider.llama:
      case AIProvider.custom:
        return Icons.memory;
    }
  }

  Widget _buildSamplePrompts() {
    final samplePrompts = [
      {
        'icon': Icons.summarize,
        'title': 'Summarize',
        'prompt': 'Summarize the key points from this document',
        'color': Colors.blue,
      },
      {
        'icon': Icons.image,
        'title': 'Describe Image',
        'prompt': 'Describe what you see in this image in detail',
        'color': Colors.purple,
      },
      {
        'icon': Icons.edit_note,
        'title': 'Writing Help',
        'prompt': 'Help me improve and rewrite this text professionally',
        'color': Colors.orange,
      },
      {
        'icon': Icons.restaurant_menu,
        'title': 'Diet Plan',
        'prompt':
            'Create a 7-day healthy diet plan based on my uploaded nutrition info',
        'color': Colors.green,
      },
      {
        'icon': Icons.receipt_long,
        'title': 'Split Bill',
        'prompt': 'Help me split this bill equally among 4 people',
        'color': Colors.teal,
      },
      {
        'icon': Icons.description,
        'title': 'Fill Form',
        'prompt':
            'Extract information from this document and help me fill the form',
        'color': Colors.indigo,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Try these:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.1,
          ),
          itemCount: samplePrompts.length,
          itemBuilder: (context, index) {
            final prompt = samplePrompts[index];
            final color = prompt['color'] as Color;

            return InkWell(
              onTap: () {
                _messageController.text = prompt['prompt'] as String;
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.1),
                      color.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(prompt['icon'] as IconData, size: 28, color: color),
                    const SizedBox(height: 8),
                    Text(
                      prompt['title'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: color.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prompt['prompt'] as String,
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(questMessagesProvider(widget.questId));
    final questAsync = ref.watch(questDetailsProvider(widget.questId));
    final selectedProvider = ref.watch(selectedAIProviderProvider);
    final bestProvider = ref.watch(bestAIProviderProvider);

    return Scaffold(
      appBar: AppBar(
        title: questAsync.when(
          data: (quest) => Text(quest?.title ?? 'Quest'),
          loading: () => const Text('Loading...'),
          error: (_, _) => const Text('Quest'),
        ),
        centerTitle: true,
        actions: [
          // AI Provider Selector Button
          IconButton(
            icon: Stack(
              children: [
                Icon(_getProviderIcon(selectedProvider)),
                if (selectedProvider == AIProvider.nano)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'AI Provider: ${bestProvider.displayName}',
            onPressed: () => showAIProviderSelector(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messages.isEmpty
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Icon(
                          Icons.auto_awesome,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ask questions about your uploaded files',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 32),
                        // Sample prompts
                        _buildSamplePrompts(),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),

          // Loading indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI is thinking...',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),

          // Attached files display
          if (_attachedFiles.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: _attachedFiles
                    .map(
                      (file) => Chip(
                        label: Text(file['name'] ?? 'File'),
                        onDeleted: () {
                          setState(() {
                            _attachedFiles.remove(file);
                          });
                        },
                        avatar: const Icon(Icons.attach_file, size: 18),
                      ),
                    )
                    .toList(),
              ),
            ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                AttachmentButton(
                  onFileSelected: (fileName, filePath) {
                    setState(() {
                      _attachedFiles.add({'name': fileName, 'path': filePath});
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Attached: $fileName')),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask a question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    enabled: !_isLoading,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _isLoading ? null : _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(QuestMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: message.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: message.isUser
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    color: message.isUser ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: message.isUser ? Colors.white70 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          // Create reminder button for AI responses
          if (!message.isUser)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: TextButton.icon(
                onPressed: () => _showReminderDialog(message),
                icon: const Icon(Icons.notifications_active, size: 16),
                label: const Text('Create Reminder'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showReminderDialog(QuestMessage message) {
    showDialog(
      context: context,
      builder: (context) => ReminderDialog(
        questId: widget.questId,
        suggestedTitle: 'Diet Plan Reminder',
        suggestedDescription: message.text.substring(0, 100),
        onCreateReminder: (title, description, time, recurring) async {
          try {
            await ref.read(
              createReminderProvider((
                widget.questId,
                title,
                description,
                time,
              )).future,
            );
            if (mounted) {
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reminder created successfully!')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                // ignore: use_build_context_synchronously
                context,
              ).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
