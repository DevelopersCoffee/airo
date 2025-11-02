import 'package:flutter/material.dart';
import '../gemini_nano_service.dart';
// Using standard Flutter widgets instead of custom ones

class GeminiNanoChatScreen extends StatefulWidget {
  const GeminiNanoChatScreen({super.key});

  @override
  State<GeminiNanoChatScreen> createState() => _GeminiNanoChatScreenState();
}

class _GeminiNanoChatScreenState extends State<GeminiNanoChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isAvailable = false;
  bool _useStreaming = true;
  String? _deviceInfo;

  @override
  void initState() {
    super.initState();
    _initializeGeminiNano();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    GeminiNanoService.instance.close();
    super.dispose();
  }

  Future<void> _initializeGeminiNano() async {
    setState(() => _isLoading = true);

    try {
      // Check availability
      _isAvailable = await GeminiNanoService.instance.isAvailable();

      if (_isAvailable) {
        // Initialize with default config
        _isInitialized = await GeminiNanoService.instance.initialize();

        // Get device info
        final deviceInfo = await GeminiNanoService.instance.getDeviceInfo();
        _deviceInfo =
            'Device: ${deviceInfo['brand']} ${deviceInfo['model']}\n'
            'Android: ${deviceInfo['release']} (API ${deviceInfo['sdkVersion']})\n'
            'Pixel Compatible: ${deviceInfo['isPixel']}\n'
            'Gemini Nano: ${deviceInfo['supportsGeminiNano']}';

        if (_isInitialized) {
          _addMessage(
            ChatMessage(
              text:
                  'Gemini Nano is ready! This AI runs locally on your Pixel 9 device.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        } else {
          _addMessage(
            ChatMessage(
              text:
                  'Failed to initialize Gemini Nano. Please check your device compatibility.',
              isUser: false,
              timestamp: DateTime.now(),
              isError: true,
            ),
          );
        }
      } else {
        _addMessage(
          ChatMessage(
            text:
                'Gemini Nano is not available on this device. This feature requires a Pixel 9 or compatible device with Android 12+.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
      }
    } catch (e) {
      _addMessage(
        ChatMessage(
          text: 'Error initializing Gemini Nano: $e',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    if (message.isEmpty || !_isInitialized) return;

    _messageController.clear();

    // Add user message
    _addMessage(
      ChatMessage(text: message, isUser: true, timestamp: DateTime.now()),
    );

    setState(() => _isLoading = true);

    try {
      if (_useStreaming) {
        // Add placeholder for streaming response
        final responseMessage = ChatMessage(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
        );
        _addMessage(responseMessage);

        // Stream response
        await for (final chunk
            in GeminiNanoService.instance.generateContentStream(message)) {
          setState(() {
            _messages.last = _messages.last.copyWith(text: chunk);
          });
          _scrollToBottom();
        }
      } else {
        // Generate single response
        final response = await GeminiNanoService.instance.generateContent(
          message,
        );
        _addMessage(
          ChatMessage(
            text: response ?? 'No response generated',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      _addMessage(
        ChatMessage(
          text: 'Error: $e',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini Nano Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showDeviceInfo(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'streaming') {
                setState(() => _useStreaming = !_useStreaming);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'streaming',
                child: Row(
                  children: [
                    Icon(
                      _useStreaming
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                    ),
                    const SizedBox(width: 8),
                    const Text('Streaming'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isAvailable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Text(
                'Gemini Nano requires a Pixel 9 or compatible device with Android 12+',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ChatBubble(message: message);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: _isInitialized
                    ? 'Ask Gemini Nano anything...'
                    : 'Gemini Nano not available',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              enabled: _isInitialized && !_isLoading,
              onSubmitted: (_) => _sendMessage(),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isInitialized && !_isLoading ? _sendMessage : null,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  void _showDeviceInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Device Information'),
        content: Text(_deviceInfo ?? 'Loading device information...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
    bool? isError,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isError: isError ?? this.isError,
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: message.isError
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
              child: Icon(
                message.isError ? Icons.error : Icons.smart_toy,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).colorScheme.primary
                    : message.isError
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser
                      ? Theme.of(context).colorScheme.onPrimary
                      : message.isError
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
