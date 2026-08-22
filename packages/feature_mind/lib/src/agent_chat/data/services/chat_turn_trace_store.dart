import 'dart:convert';

import 'package:core_ai/core_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local redacted turn traces, keyed by [ChatTurnTrace.runId].
///
/// Full prompts stay behind refs and are not written here. A failing write
/// must not fail generation — callers catch and log.
class ChatTurnTraceStore {
  ChatTurnTraceStore({this.preferences});

  static const storageKey = 'airo_mind.chat_turn_traces.v1';
  static const schemaVersion = 1;
  static const maxTraces = 200;

  final SharedPreferences? preferences;
  Future<void> _writeTail = Future<void>.value();

  Future<ChatTurnTrace?> byRunId(String runId) async {
    await _writeTail;
    final traces = await _loadAll();
    return traces[runId];
  }

  Future<void> upsert(ChatTurnTrace trace) {
    if (!kMindChatTurnInspector) return Future<void>.value();
    return _enqueueWrite(() async {
      final traces = await _loadAll();
      traces[trace.runId] = trace;
      while (traces.length > maxTraces) {
        final oldest = traces.values.reduce(
          (a, b) => a.startedAt.isBefore(b.startedAt) ? a : b,
        );
        traces.remove(oldest.runId);
      }
      await _writeAll(traces);
    });
  }

  Future<void> clear() {
    return _enqueueWrite(() async {
      final store = preferences ?? await SharedPreferences.getInstance();
      await store.remove(storageKey);
    });
  }

  Future<Map<String, ChatTurnTrace>> _loadAll() async {
    final store = preferences ?? await SharedPreferences.getInstance();
    final raw = store.getString(storageKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['schemaVersion'] != schemaVersion) {
        return {};
      }
      final traces = decoded['traces'];
      if (traces is! Map) return {};
      return {
        for (final entry in traces.entries)
          if (entry.key is String && entry.value is Map)
            entry.key as String: ChatTurnTrace.fromJson(
              Map<String, Object?>.from(entry.value as Map),
            ),
      };
    } on Object {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, ChatTurnTrace> traces) async {
    final store = preferences ?? await SharedPreferences.getInstance();
    await store.setString(
      storageKey,
      jsonEncode({
        'schemaVersion': schemaVersion,
        'traces': {
          for (final entry in traces.entries) entry.key: entry.value.toJson(),
        },
      }),
    );
  }

  Future<void> _enqueueWrite(Future<void> Function() operation) {
    final result = _writeTail.then<void>((_) => operation());
    _writeTail = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }
}
