import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/log_models.dart';
import '../ports/operation_log_port.dart';
import 'rust/rust_mind_runtime_operation_log.dart';

/// JSON wire shape for a persisted [MindOp].
@immutable
class MindOpRecord {
  const MindOpRecord({
    required this.sequence,
    required this.kind,
    required this.title,
    required this.contextId,
    required this.deviceName,
    required this.signature,
    required this.recordedAtMs,
    this.detail = '',
  });

  final int sequence;
  final MindOpKind kind;
  final String title;
  final String contextId;
  final String deviceName;
  final SignatureState signature;
  final int recordedAtMs;
  final String detail;

  MindOp toMindOp() => MindOp(
    sequence: sequence,
    kind: kind,
    title: title,
    contextId: contextId,
    deviceName: deviceName,
    signature: signature,
    recordedAtMs: recordedAtMs,
    detail: detail,
  );

  factory MindOpRecord.fromMindOp(MindOp op) => MindOpRecord(
    sequence: op.sequence,
    kind: op.kind,
    title: op.title,
    contextId: op.contextId,
    deviceName: op.deviceName,
    signature: op.signature,
    recordedAtMs: op.recordedAtMs,
    detail: op.detail,
  );

  Map<String, Object?> toJson() => {
    'sequence': sequence,
    'kind': kind.name,
    'title': title,
    'contextId': contextId,
    'deviceName': deviceName,
    'signature': signature.name,
    'recordedAtMs': recordedAtMs,
    'detail': detail,
  };

  static MindOpRecord fromJson(Map<String, Object?> json) {
    return MindOpRecord(
      sequence: json['sequence'] as int,
      kind: MindOpKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => throw FormatException('unknown MindOpKind: ${json['kind']}'),
      ),
      title: json['title'] as String? ?? '',
      contextId: json['contextId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      signature: SignatureState.values.firstWhere(
        (s) => s.name == json['signature'],
        orElse: () => SignatureState.unsigned,
      ),
      recordedAtMs: json['recordedAtMs'] as int? ?? 0,
      detail: json['detail'] as String? ?? '',
    );
  }
}

/// Append-only JSON-lines operation log for the Mind scribe shell.
///
/// Wave 2 wire-up: `meetingIrExtracted` and consent ops survive process restarts
/// until the Rust operation log (#1213) lands. Same discipline as
/// [NotesOperationLog].
class PersistentOperationLog implements OperationLogPort {
  PersistentOperationLog._(this._file, List<MindOp> ops) : _ops = ops;

  final File _file;
  final List<MindOp> _ops;

  /// Opens [path], replaying existing entries to recover sequence numbers.
  static Future<PersistentOperationLog> open(String path) async {
    final file = File(path);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    final ops = await _replay(file);
    return PersistentOperationLog._(file, ops);
  }

  /// Default location beside Mind model artifacts.
  static Future<PersistentOperationLog> openDefault() async {
    final base = await getApplicationSupportDirectory();
    final path = p.join(base.path, 'airo_mind', 'mind_ops.jsonl');
    return open(path);
  }

  static Future<List<MindOp>> _replay(File file) async {
    if (!await file.exists()) return [];
    final lines = await file
        .readAsLines()
        .then((raw) => raw.where((line) => line.trim().isNotEmpty));
    final ops = <MindOp>[];
    for (final line in lines) {
      try {
        final json = jsonDecode(line) as Map<String, Object?>;
        ops.add(MindOpRecord.fromJson(json).toMindOp());
      } on Object {
        // Torn tail — treat as end of durable log.
        break;
      }
    }
    ops.sort((a, b) => a.sequence.compareTo(b.sequence));
    return ops;
  }

  int _nextSequence() =>
      _ops.isEmpty ? 1 : _ops.map((op) => op.sequence).reduce((a, b) => a > b ? a : b) + 1;

  @override
  Future<int> count() async => _ops.length;

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async {
    if (limit <= 0 || offset >= _ops.length) return const [];
    final sorted = _ops.toList()..sort((a, b) => b.sequence.compareTo(a.sequence));
    final end = (offset + limit).clamp(0, sorted.length);
    return sorted.sublist(offset, end);
  }

  @override
  Future<MindOp?> bySequence(int sequence) async {
    for (final op in _ops) {
      if (op.sequence == sequence) return op;
    }
    return null;
  }

  @override
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail = '',
  }) async {
    final op = MindOp(
      sequence: _nextSequence(),
      kind: kind,
      title: title,
      contextId: contextId,
      deviceName: 'this device',
      signature: SignatureState.unsigned,
      recordedAtMs: DateTime.now().millisecondsSinceEpoch,
      detail: detail,
    );
    final record = MindOpRecord.fromMindOp(op);
    final raf = await _file.open(mode: FileMode.writeOnlyAppend);
    try {
      await raf.writeString('${jsonEncode(record.toJson())}\n');
      await raf.flush();
    } finally {
      await raf.close();
    }
    _ops.add(op);
    return op.sequence;
  }

  @override
  Future<SignatureState> verify(int sequence) async =>
      (await bySequence(sequence))?.signature ?? SignatureState.unsigned;

  @override
  Stream<double> replayFrom(int sequence) async* {
    for (var step = 0; step <= 10; step++) {
      yield step / 10;
    }
  }
}

/// Defers opening [PersistentOperationLog] until the first append/read.
///
/// Shared by [MindService] and [mindRuntimeProvider] so meeting IR ops and
/// assistant consent entries land in one durable file.
class LazyPersistentOperationLog implements OperationLogPort {
  LazyPersistentOperationLog({Future<PersistentOperationLog>? opener})
    : _opener = opener ?? PersistentOperationLog.openDefault();

  final Future<PersistentOperationLog> _opener;
  PersistentOperationLog? _opened;

  Future<PersistentOperationLog> _ensure() async {
    _opened ??= await _opener;
    return _opened!;
  }

  @override
  Future<int> count() async => (await _ensure()).count();

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async =>
      (await _ensure()).range(offset: offset, limit: limit);

  @override
  Future<MindOp?> bySequence(int sequence) async =>
      (await _ensure()).bySequence(sequence);

  @override
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail = '',
  }) async =>
      (await _ensure()).append(
        kind: kind,
        title: title,
        contextId: contextId,
        detail: detail,
      );

  @override
  Future<SignatureState> verify(int sequence) async =>
      (await _ensure()).verify(sequence);

  @override
  Stream<double> replayFrom(int sequence) =>
      _ensure().asStream().asyncExpand((log) => log.replayFrom(sequence));
}

final _fallbackMindOperationLog = LazyPersistentOperationLog();
RustMindRuntimeOperationLog? _sharedMindOperationLog;

/// One shared log instance for the Mind shell composition root.
OperationLogPort sharedMindOperationLog() {
  _sharedMindOperationLog ??=
      RustMindRuntimeOperationLog(_fallbackMindOperationLog);
  return _sharedMindOperationLog!;
}
