import '../../domain/models/chat_entity_graph.dart';
import '../../domain/services/chat_entity_linker.dart';
import 'chat_entity_graph_store.dart';

/// Process-wide chat memory graph so ingest and query share the same nodes.
class ChatEntityGraphSession {
  ChatEntityGraphSession({
    ChatEntityGraphStore? store,
    ChatEntityLinker linker = const ChatEntityLinker(),
  }) : _store = store ?? ChatEntityGraphStore(),
       _linker = linker;

  final ChatEntityGraphStore _store;
  final ChatEntityLinker _linker;
  ChatEntityGraph graph = ChatEntityGraph.empty;
  bool _loaded = false;

  Future<ChatEntityGraph> ensureLoaded() async {
    if (_loaded) return graph;
    graph = await _store.load();
    _loaded = true;
    return graph;
  }

  Future<void> replaceGraph(ChatEntityGraph next) async {
    graph = next;
    _loaded = true;
    await _store.save(graph);
  }

  Future<ChatEntityGraph> ingest(String text) async {
    await ensureLoaded();
    graph = _linker.ingest(graph, text);
    await _store.save(graph);
    return graph;
  }

  Future<ChatEntityGraph> markAttribute(
    String nodeId,
    String key,
    String value,
  ) async {
    await ensureLoaded();
    graph = graph.withNodeAttribute(nodeId, key, value);
    await _store.save(graph);
    return graph;
  }
}

final ChatEntityGraphSession chatEntityGraphSession = ChatEntityGraphSession();
