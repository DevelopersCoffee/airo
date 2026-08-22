import 'package:core_ai/core_ai.dart';
import 'package:core_data/core_data.dart';

/// Prefs-tier adapter for [ExecutionLog] metadata (ADR-0024).
///
/// Payload is a JSON array of `{executionId, failureMode, runtimeError}`.
/// No prompt, completion, IR, or token fields.
class PreferencesReliabilityCheckpointStore
    implements ReliabilityCheckpointStore {
  PreferencesReliabilityCheckpointStore(this._store);

  /// Stable Prefs key. Bump the suffix if the codec changes.
  static const prefsKey = 'airo.mind.reliability_checkpoints.v1';

  final KeyValueStore _store;

  @override
  Future<String?> load() async {
    try {
      return await _store.getString(prefsKey);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(String encoded) async {
    try {
      await _store.setString(prefsKey, encoded);
    } on Object {
      // Best-effort. Chat turns must not fail because prefs I/O failed.
    }
  }
}
