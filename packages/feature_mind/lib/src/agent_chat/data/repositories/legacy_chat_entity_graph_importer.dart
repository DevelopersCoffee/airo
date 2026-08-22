import '../../domain/models/chat_entity_graph.dart';
import 'chat_entity_graph_store.dart';

/// One-time read of the legacy SharedPreferences graph for compatibility.
class LegacyChatEntityGraphImporter {
  const LegacyChatEntityGraphImporter({this.legacyStore});

  /// When null, legacy SharedPreferences import is skipped (memory/test sessions).
  final ChatEntityGraphStore? legacyStore;

  Future<ChatEntityGraph> importIfEmpty(ChatEntityGraph current) async {
    if (current.nodes.isNotEmpty || current.edges.isNotEmpty) return current;
    if (legacyStore == null) return current;
    final legacy = await legacyStore!.load();
    if (legacy.nodes.isEmpty && legacy.edges.isEmpty) return current;
    return legacy;
  }
}
