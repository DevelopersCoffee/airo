import '../../domain/models/chat_entity_graph.dart';
import '../../../addons/built_in_addon_registry.dart';
import '../../../addons/graph_workflow/graph_workflow_coordinator.dart';
import 'chat_entity_graph_store.dart';
import 'legacy_chat_entity_graph_importer.dart';

class _EphemeralGraphSlot {
  _EphemeralGraphSlot({required this.graph, required this.updatedAt});

  ChatEntityGraph graph;
  DateTime updatedAt;
}

/// Ephemeral add-on graph session: in-memory only, partitioned by conversation.
///
/// Pre-confirmation graph state is never written to disk (§8). Legacy
/// SharedPreferences graph is imported read-only once for compatibility.
class ChatEntityGraphSession {
  ChatEntityGraphSession({
    GraphWorkflowCoordinator? graphCoordinator,
    LegacyChatEntityGraphImporter? legacyImporter,
    Duration ephemeralTtl = const Duration(hours: 24),
    DateTime Function()? now,
  }) : _graphCoordinator =
           graphCoordinator ?? BuiltInAddonRegistry.create().graphCoordinator,
       _ephemeralTtl = ephemeralTtl,
       _now = now ?? DateTime.now,
       _legacyImporter = legacyImporter ??
           const LegacyChatEntityGraphImporter(legacyStore: null);

  static const emptyConversationKey = '__ephemeral_no_conversation__';

  final GraphWorkflowCoordinator _graphCoordinator;
  final Duration _ephemeralTtl;
  final DateTime Function() _now;
  final LegacyChatEntityGraphImporter _legacyImporter;

  final Map<String, _EphemeralGraphSlot> _slots = {};
  String? _activeConversationId;
  ChatEntityGraph _legacyGraphCache = ChatEntityGraph.empty;
  bool _legacyLoaded = false;

  ChatEntityGraph get graph => _currentSlot()?.graph ?? ChatEntityGraph.empty;

  void bindConversation(String? conversationId) {
    _activeConversationId = conversationId;
    _expireStaleSlots();
  }

  void invalidateAllEphemeralGraphs() {
    _slots.clear();
    _legacyGraphCache = ChatEntityGraph.empty;
    _legacyLoaded = false;
  }

  void clearConversation(String conversationId) {
    _slots.remove(conversationId);
  }

  Future<ChatEntityGraph> ensureLoaded({String? conversationId}) async {
    final id = conversationId ?? _activeConversationId ?? emptyConversationKey;
    _expireStaleSlots();
    final existing = _slots[id];
    if (existing != null && !_isExpired(existing)) {
      return existing.graph;
    }

    await _ensureLegacyLoaded();
    final seed = _legacyGraphCache.nodes.isEmpty || _slots.isNotEmpty
        ? ChatEntityGraph.empty
        : _legacyGraphCache;
    _slots[id] = _EphemeralGraphSlot(graph: seed, updatedAt: _now().toUtc());
    return seed;
  }

  Future<void> replaceGraph(ChatEntityGraph next, {String? conversationId}) async {
    final id = conversationId ?? _activeConversationId ?? emptyConversationKey;
    _slots[id] = _EphemeralGraphSlot(graph: next, updatedAt: _now().toUtc());
  }

  Future<ChatEntityGraph> ingest(String text, {String? conversationId}) async {
    final id = conversationId ?? _activeConversationId ?? emptyConversationKey;
    var graph = await ensureLoaded(conversationId: id);
    graph = await _graphCoordinator.ingestWithAddonPatches(graph, text);
    _slots[id] = _EphemeralGraphSlot(graph: graph, updatedAt: _now().toUtc());
    return graph;
  }

  Future<ChatEntityGraph> markAttribute(
    String nodeId,
    String key,
    String value, {
    String? conversationId,
  }) async {
    final id = conversationId ?? _activeConversationId ?? emptyConversationKey;
    var graph = await ensureLoaded(conversationId: id);
    graph = graph.withNodeAttribute(nodeId, key, value);
    _slots[id] = _EphemeralGraphSlot(graph: graph, updatedAt: _now().toUtc());
    return graph;
  }

  _EphemeralGraphSlot? _currentSlot() {
    final id = _activeConversationId ?? emptyConversationKey;
    final slot = _slots[id];
    if (slot == null || _isExpired(slot)) return null;
    return slot;
  }

  bool _isExpired(_EphemeralGraphSlot slot) =>
      _now().toUtc().difference(slot.updatedAt) > _ephemeralTtl;

  void _expireStaleSlots() {
    final staleKeys = _slots.entries
        .where((entry) => _isExpired(entry.value))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in staleKeys) {
      _slots.remove(key);
    }
  }

  Future<void> warmLegacyImport() async {
    if (_legacyLoaded) return;
    final importer = LegacyChatEntityGraphImporter(
      legacyStore: ChatEntityGraphStore(),
    );
    _legacyGraphCache = await importer.importIfEmpty(ChatEntityGraph.empty);
    _legacyLoaded = true;
  }

  Future<void> _ensureLegacyLoaded() async {
    if (_legacyLoaded) return;
    _legacyLoaded = true;
    _legacyGraphCache = await _legacyImporter.importIfEmpty(
      ChatEntityGraph.empty,
    );
  }
}

final ChatEntityGraphSession chatEntityGraphSession = ChatEntityGraphSession();
