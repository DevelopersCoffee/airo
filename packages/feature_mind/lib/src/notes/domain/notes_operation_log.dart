import 'dart:convert';
import 'dart:io';

import 'notes_operation.dart';

/// Sequential, append-only, file-backed operation log for the Notes
/// capability. `#1338`'s runtime skeleton, Dart half.
///
/// This is the UI-facing twin of `airo_mind_core::runtime::OperationLog`
/// (`rust/airo_mind_core/src/runtime.rs`). The two are independent
/// implementations of the same contract rather than one bridged through FFI
/// -- wiring a new `flutter_rust_bridge` engine crate (cargokit, Android
/// Gradle, iOS podspec, codegen) is real platform-integration work this pass
/// deliberately did not attempt; see the `#1338` completion notes for why.
/// What this type proves on the Dart side is the property the UI actually
/// needs: notes persist, survive a projection wipe, and are replayable from
/// scratch, in one pass, in write order.
///
/// `C1`: *"writes are sequential and append-only; no in-place rewrite."*
/// Each [append] opens the file in append mode, writes one JSON-lines
/// record, and flushes before returning -- there is no separate durability
/// point deferred to later.
class NotesOperationLog {
  NotesOperationLog._(this._file);

  final File _file;
  int _nextSeq = 0;

  /// Opens the log at [path], creating it if absent. If it already has
  /// entries, replays them once to recover the next sequence number, so a
  /// restart resumes numbering rather than colliding with what is durable.
  static Future<NotesOperationLog> open(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    final log = NotesOperationLog._(file);
    final existing = await log.replay();
    log._nextSeq = existing.isEmpty ? 0 : existing.last.seq + 1;
    return log;
  }

  /// Appends one operation and returns it with its assigned [NotesOperation.seq].
  Future<NotesOperation> append({
    required NoteOpKind kind,
    required String id,
    required int recordedAtMs,
    String title = '',
    String body = '',
  }) async {
    final op = NotesOperation(
      seq: _nextSeq++,
      kind: kind,
      id: id,
      title: title,
      body: body,
      recordedAtMs: recordedAtMs,
    );
    final raf = await _file.open(mode: FileMode.writeOnlyAppend);
    try {
      await raf.writeString('${jsonEncode(op.toJson())}\n');
      await raf.flush();
    } finally {
      await raf.close();
    }
    return op;
  }

  /// Replays every durable operation, in write order, in a single pass over
  /// the file. `C2`: *"replay is a single pass"* -- one read of the file,
  /// one iteration over its lines.
  ///
  /// A torn final line -- a write interrupted mid-flush -- is treated as the
  /// end of the durable log rather than a hard failure, the same recovery
  /// rule `airo_mind_core::runtime::OperationLog` uses for a torn tail.
  Future<List<NotesOperation>> replay() async {
    if (!await _file.exists()) {
      return const [];
    }
    final lines = await _file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .toList();

    final ops = <NotesOperation>[];
    for (final line in lines) {
      if (line.isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, Object?>;
        ops.add(NotesOperation.fromJson(json));
      } on FormatException {
        // Torn tail: stop at the last complete record, matching what a
        // reader restarting after a kill would see as durable.
        break;
      }
    }
    return ops;
  }

  Future<int> count() async => (await replay()).length;
}
