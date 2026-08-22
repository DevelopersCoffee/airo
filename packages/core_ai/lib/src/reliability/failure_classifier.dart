import 'dart:convert';

import 'package:meta/meta.dart';

import 'reasoning_reliability.dart';

/// In-process diagnostic. Never includes prompt or completion text.
@immutable
class PersistableDiagnostic {
  const PersistableDiagnostic({
    required this.executionId,
    this.failureMode,
    this.runtimeError,
  });

  final String executionId;
  final FailureMode? failureMode;
  final RuntimeFailure? runtimeError;

  Map<String, String> toJson() => {
    'executionId': executionId,
    if (failureMode != null) 'failureMode': failureMode!.id,
    if (runtimeError != null) 'runtimeError': runtimeError!.id,
  };

  factory PersistableDiagnostic.fromJson(Map<String, dynamic> json) {
    return PersistableDiagnostic(
      executionId: json['executionId'] as String? ?? '',
      failureMode: FailureMode.fromId(json['failureMode'] as String? ?? ''),
      runtimeError: RuntimeFailure.fromId(
        json['runtimeError'] as String? ?? '',
      ),
    );
  }
}

/// Prefs-tier (or in-memory) codec for the checkpoint ring. ADR-0024.
abstract class ReliabilityCheckpointStore {
  Future<String?> load();
  Future<void> save(String encoded);
}

/// Test double. Does not touch SharedPreferences.
class MemoryReliabilityCheckpointStore implements ReliabilityCheckpointStore {
  MemoryReliabilityCheckpointStore([this.encoded]);

  String? encoded;

  @override
  Future<String?> load() async => encoded;

  @override
  Future<void> save(String encoded) async {
    this.encoded = encoded;
  }
}

/// Bounded in-process checkpoint log. Mirror of Rust `ExecutionLog`.
///
/// Not an operation-log writer (ADR-0023). Disk durability is Prefs-tier
/// metadata only (ADR-0024).
class ExecutionLog {
  ExecutionLog({this.capacity = 32});

  final int capacity;
  final List<PersistableDiagnostic> _checkpoints = [];

  void record(PersistableDiagnostic? diagnostic) {
    if (diagnostic == null) return;
    _checkpoints.add(diagnostic);
    if (_checkpoints.length > capacity) {
      _checkpoints.removeRange(0, _checkpoints.length - capacity);
    }
  }

  List<PersistableDiagnostic> get checkpoints =>
      List<PersistableDiagnostic>.unmodifiable(_checkpoints);

  PersistableDiagnostic? get last =>
      _checkpoints.isEmpty ? null : _checkpoints.last;

  PersistableDiagnostic? get lastFailure {
    for (var i = _checkpoints.length - 1; i >= 0; i--) {
      if (_checkpoints[i].failureMode != null) return _checkpoints[i];
    }
    return null;
  }

  bool get isEmpty => _checkpoints.isEmpty;

  String encode() => jsonEncode(
    _checkpoints.map((checkpoint) => checkpoint.toJson()).toList(),
  );

  /// Prefs hydrate. Disk entries are older; in-memory entries stay at the end.
  /// Does not replace a non-empty ring (late attach after a classifier hit).
  void restoreFromDisk(Iterable<PersistableDiagnostic> restored) {
    final older = restored
        .where((diagnostic) => diagnostic.executionId.isNotEmpty)
        .toList(growable: false);
    if (older.isEmpty) return;
    if (_checkpoints.isEmpty) {
      for (final diagnostic in older) {
        record(diagnostic);
      }
      return;
    }
    final combined = [...older, ..._checkpoints];
    _checkpoints
      ..clear()
      ..addAll(
        combined.length > capacity
            ? combined.sublist(combined.length - capacity)
            : combined,
      );
  }

  static List<PersistableDiagnostic> decode(String raw) {
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            PersistableDiagnostic.fromJson(Map<String, dynamic>.from(item)),
      ].where((d) => d.executionId.isNotEmpty).toList(growable: false);
    } on Object {
      return const [];
    }
  }
}

/// Dart mirror of `record_chat_completion` for Cloud / LiteRT / Gemini.
/// No new FFI events.
abstract final class FailureClassifier {
  static PersistableDiagnostic? recordChatCompletion({
    required String executionId,
    required String text,
    required bool engineOk,
  }) {
    if (!engineOk) {
      return PersistableDiagnostic(
        executionId: executionId,
        failureMode: FailureMode.pm08BlackBox,
        runtimeError: RuntimeFailure.r07ModelAdapter,
      );
    }
    if (text.trim().isEmpty) {
      return PersistableDiagnostic(
        executionId: executionId,
        failureMode: FailureMode.pm06LogicCollapse,
        runtimeError: RuntimeFailure.r06VerificationFailure,
      );
    }
    return null;
  }
}
