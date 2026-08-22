import '../../domain/models/chat_entity_graph.dart';
import '../../../addons/built_in_addon_registry.dart';
import '../../../addons/graph_workflow/graph_workflow_coordinator.dart';
import 'chat_entity_graph_store.dart';
import 'legacy_chat_entity_graph_importer.dart';

/// Process-wide chat memory graph so ingest and query share the same nodes.
class ChatEntityGraphSession {
  ChatEntityGraphSession({
    ChatEntityGraphStore? store,
    LegacyChatEntityGraphImporter? legacyImporter,
    GraphWorkflowCoordinator? graphCoordinator,
  }) : _store = store ?? ChatEntityGraphStore.memory(),
       _legacyImporter = legacyImporter ?? _legacyImporterFor(store),
       _graphCoordinator =
           graphCoordinator ?? BuiltInAddonRegistry.create().graphCoordinator;

  static LegacyChatEntityGraphImporter _legacyImporterFor(
    ChatEntityGraphStore? store,
  ) {
    final resolved = store ?? ChatEntityGraphStore.memory();
    if (resolved.isMemoryOnly) {
      return const LegacyChatEntityGraphImporter(legacyStore: null);
    }
    return const LegacyChatEntityGraphImporter();
  }

  final ChatEntityGraphStore _store;
  final LegacyChatEntityGraphImporter _legacyImporter;
  final GraphWorkflowCoordinator _graphCoordinator;
  ChatEntityGraph graph = ChatEntityGraph.empty;
  bool _loaded = false;

  Future<ChatEntityGraph> ensureLoaded() async {
    if (_loaded) return graph;
    final memory = await _store.load();
    graph = await _legacyImporter.importIfEmpty(memory);
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
    graph = await _graphCoordinator.ingestWithAddonPatches(graph, text);
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
