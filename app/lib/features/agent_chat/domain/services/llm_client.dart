import '../models/chat_models.dart';

/// LLM client interface for streaming replies
abstract interface class LLMClient {
  /// Stream reply from LLM
  ///
  /// [conversationId] - ID of the conversation
  /// [prompt] - User prompt/message
  /// [context] - Optional context data (e.g., user data, tool results)
  ///
  /// Returns a stream of text chunks
  Stream<String> streamReply({
    required String conversationId,
    required String prompt,
    Map<String, dynamic>? context,
  });

  /// Get available tools
  Future<List<Tool>> getAvailableTools();

  /// Execute a tool
  Future<ToolResult> executeTool(ToolCall toolCall);
}

/// Tool interface for agent actions
abstract interface class Tool {
  /// Tool name (used by LLM to identify)
  String get name;

  /// Tool description (used by LLM to understand purpose)
  String get description;

  /// Tool schema (JSON schema for parameters)
  Map<String, dynamic> get schema;

  /// Execute the tool
  ///
  /// [args] - Tool arguments as specified in schema
  ///
  /// Returns result as JSON-serializable map
  Future<Map<String, dynamic>> call(Map<String, dynamic> args);
}

/// Fake LLM client for development
class FakeLLMClient implements LLMClient {
  @override
  Stream<String> streamReply({
    required String conversationId,
    required String prompt,
    Map<String, dynamic>? context,
  }) async* {
    // Simulate streaming response
    final response =
        'I\'m a fake LLM. You said: "$prompt". This is a placeholder response.';

    for (final char in response.split('')) {
      await Future.delayed(const Duration(milliseconds: 10));
      yield char;
    }
  }

  @override
  Future<List<Tool>> getAvailableTools() async {
    return [];
  }

  @override
  Future<ToolResult> executeTool(ToolCall toolCall) async {
    return ToolResult(
      toolCallId: toolCall.id,
      result: 'Tool execution not implemented in fake client',
      isError: true,
    );
  }
}

/// Money tool for agent to access money features
class MoneyTool implements Tool {
  @override
  String get name => 'Coins';

  @override
  String get description =>
      'Access money management features: check balance, view transactions, create budgets';

  @override
  Map<String, dynamic> get schema => {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['check_balance', 'view_transactions', 'create_budget'],
        'description': 'The action to perform',
      },
      'params': {'type': 'object', 'description': 'Action-specific parameters'},
    },
    'required': ['action'],
  };

  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> args) async {
    final action = args['action'] as String?;
    final params = args['params'] as Map<String, dynamic>? ?? {};

    return switch (action) {
      'check_balance' => {'balance': '\$0.00', 'currency': 'USD'},
      'view_transactions' => {'transactions': [], 'count': 0},
      'create_budget' => {'success': true, 'budgetId': 'budget_123'},
      _ => {'error': 'Unknown action: $action'},
    };
  }
}

/// Music tool for agent to control music
class MusicTool implements Tool {
  @override
  String get name => 'Beats';

  @override
  String get description =>
      'Control music playback: play, pause, skip, search for songs';

  @override
  Map<String, dynamic> get schema => {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['play', 'pause', 'skip', 'search'],
        'description': 'The action to perform',
      },
      'query': {
        'type': 'string',
        'description': 'Search query (for search action)',
      },
    },
    'required': ['action'],
  };

  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> args) async {
    final action = args['action'] as String?;
    final query = args['query'] as String?;

    return switch (action) {
      'play' => {'status': 'playing'},
      'pause' => {'status': 'paused'},
      'skip' => {'status': 'skipped'},
      'search' => {'results': [], 'query': query},
      _ => {'error': 'Unknown action: $action'},
    };
  }
}

/// Reader tool for agent to control reader
class ReaderTool implements Tool {
  @override
  String get name => 'Tales';

  @override
  String get description =>
      'Control reader: search for content, navigate chapters, adjust settings';

  @override
  Map<String, dynamic> get schema => {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['search', 'next_chapter', 'prev_chapter', 'set_brightness'],
        'description': 'The action to perform',
      },
      'query': {
        'type': 'string',
        'description': 'Search query (for search action)',
      },
      'brightness': {
        'type': 'number',
        'description': 'Brightness level 0-1 (for set_brightness action)',
      },
    },
    'required': ['action'],
  };

  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> args) async {
    final action = args['action'] as String?;

    return switch (action) {
      'search' => {'results': [], 'count': 0},
      'next_chapter' => {'success': true},
      'prev_chapter' => {'success': true},
      'set_brightness' => {'brightness': args['brightness'] ?? 0.5},
      _ => {'error': 'Unknown action: $action'},
    };
  }
}
