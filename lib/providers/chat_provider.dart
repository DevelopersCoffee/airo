import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/database_service.dart';
import '../services/ai_service.dart';

class ChatMessage {
  final String id;
  final String content;
  final String role; // 'user' or 'assistant'
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
  });
}

class ChatProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final AIService _aiService = AIService();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  String? _userId;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize chat provider with user ID
  Future<void> initialize(String userId) async {
    try {
      _userId = userId;
      developer.log('Initializing ChatProvider for user: $userId', name: 'ChatProvider');

      // Initialize AI service
      await _aiService.initialize();

      // Load existing messages
      await _loadMessages();

      notifyListeners();
    } catch (e) {
      developer.log('Error initializing ChatProvider: $e', name: 'ChatProvider');
      _error = 'Failed to initialize chat';
      notifyListeners();
    }
  }

  /// Load messages from database
  Future<void> _loadMessages() async {
    try {
      if (_userId == null) return;

      final messagesList = await _databaseService.getMessages(_userId!);
      _messages = messagesList
          .map((msg) => ChatMessage(
                id: msg['id'].toString(),
                content: msg['content'] as String,
                role: msg['role'] as String,
                timestamp: DateTime.parse(msg['createdAt'] as String),
              ))
          .toList();

      developer.log('Loaded ${_messages.length} messages', name: 'ChatProvider');
      notifyListeners();
    } catch (e) {
      developer.log('Error loading messages: $e', name: 'ChatProvider');
      _error = 'Failed to load messages';
      notifyListeners();
    }
  }

  /// Send message and get AI response
  Future<void> sendMessage(String userMessage) async {
    try {
      if (_userId == null) {
        _error = 'User not authenticated';
        notifyListeners();
        return;
      }

      _isLoading = true;
      _error = null;
      notifyListeners();

      developer.log('Sending message: $userMessage', name: 'ChatProvider');

      // Add user message to database and UI
      final userMsgId = await _databaseService.insertMessage(
        _userId!,
        userMessage,
        'user',
      );

      final userMsg = ChatMessage(
        id: userMsgId.toString(),
        content: userMessage,
        role: 'user',
        timestamp: DateTime.now(),
      );

      _messages.add(userMsg);
      notifyListeners();

      // Generate AI response
      final aiResponse = await _aiService.generateChatResponse(userMessage);

      // Add AI response to database and UI
      final aiMsgId = await _databaseService.insertMessage(
        _userId!,
        aiResponse,
        'assistant',
      );

      final aiMsg = ChatMessage(
        id: aiMsgId.toString(),
        content: aiResponse,
        role: 'assistant',
        timestamp: DateTime.now(),
      );

      _messages.add(aiMsg);
      _isLoading = false;
      notifyListeners();

      developer.log('Message exchange completed', name: 'ChatProvider');
    } catch (e) {
      developer.log('Error sending message: $e', name: 'ChatProvider');
      _error = 'Failed to send message';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear all messages
  Future<void> clearMessages() async {
    try {
      _messages.clear();
      notifyListeners();
      developer.log('Messages cleared', name: 'ChatProvider');
    } catch (e) {
      developer.log('Error clearing messages: $e', name: 'ChatProvider');
      _error = 'Failed to clear messages';
      notifyListeners();
    }
  }

  /// Get AI service info
  bool get hasGeminiNano => _aiService.hasGeminiNano;
  bool get aiServiceInitialized => _aiService.isInitialized;
}

