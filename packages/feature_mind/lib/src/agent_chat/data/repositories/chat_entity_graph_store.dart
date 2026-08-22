import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/chat_entity_graph.dart';

class ChatEntityGraphStore {
  ChatEntityGraphStore() : _memoryOnly = false;

  ChatEntityGraphStore.memory() : _memoryOnly = true;

  static const key = 'agent_chat.entity_graph.v1';

  final bool _memoryOnly;
  bool get isMemoryOnly => _memoryOnly;
  ChatEntityGraph _memory = ChatEntityGraph.empty;

  Future<ChatEntityGraph> load() async {
    if (_memoryOnly) return _memory;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
    if (raw == null || raw.trim().isEmpty) return ChatEntityGraph.empty;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return ChatEntityGraph.empty;
    return ChatEntityGraph.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> save(ChatEntityGraph graph) async {
    if (_memoryOnly) {
      _memory = graph;
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    if (graph.nodes.isEmpty && graph.edges.isEmpty) {
      await preferences.remove(key);
      return;
    }
    await preferences.setString(key, encodeCompactJson(graph.toJson()));
  }
}
