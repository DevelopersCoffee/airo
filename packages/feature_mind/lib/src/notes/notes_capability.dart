import 'dart:convert';

import '../runtime/rust/rust_mind_runtime_ready.dart';
import '../whisper/api/mind_runtime.dart';
import 'domain/notes_operation.dart';
import 'domain/notes_operation_log.dart';
import 'domain/notes_projection.dart';

/// The Notes capability. `#1338`'s vertical slice: the one capability that
/// exercises Operation → Persist → Replay → Projection end to end.
///
/// `C5`: a capability emits operations and consumes projections, nothing
/// else. [NotesCapability] holds a [NotesOperationLog] handle and nothing
/// else durable (`I2`, `I4`) -- every note it creates, edits, or deletes
/// exists only as a [NotesOperation] in the log. There is no cache field on
/// this class for [notes] to read from; every call is a fresh fold.
///
/// When [rustPreferred] is true and the Mind Rust runtime is ready, mutations
/// and reads go through `airo_mind_core::notes` via FFI; legacy `notes.log`
/// rows migrate into Rust on first boot.
class NotesCapability {
  const NotesCapability(this._log, {this.rustPreferred = false});

  final NotesOperationLog _log;
  final bool rustPreferred;

  /// Dart JSONL log with Rust operation log preferred when Mind is initialised.
  factory NotesCapability.rustPreferred(NotesOperationLog fallback) =>
      NotesCapability(fallback, rustPreferred: true);

  bool get _rustReady => rustPreferred && mindRuntimeRustReady();

  /// Emits a `create` operation. The only way a note comes into existence --
  /// there is no direct write path to [NotesProjection].
  Future<NotesOperation> createNote({
    required String id,
    required String title,
    required String body,
    required int recordedAtMs,
  }) async {
    if (_rustReady) {
      try {
        mindRuntimeCreateNote(
          id: id,
          title: title,
          body: body,
          recordedAtMs: BigInt.from(recordedAtMs),
        );
        return NotesOperation(
          seq: 0,
          kind: NoteOpKind.create,
          id: id,
          title: title,
          body: body,
          recordedAtMs: recordedAtMs,
        );
      } on Object {
        // Fall through to Dart log.
      }
    }
    return _log.append(
      kind: NoteOpKind.create,
      id: id,
      title: title,
      body: body,
      recordedAtMs: recordedAtMs,
    );
  }

  Future<NotesOperation> editNote({
    required String id,
    required String title,
    required String body,
    required int recordedAtMs,
  }) async {
    if (_rustReady) {
      try {
        mindRuntimeEditNote(
          id: id,
          title: title,
          body: body,
          recordedAtMs: BigInt.from(recordedAtMs),
        );
        return NotesOperation(
          seq: 0,
          kind: NoteOpKind.edit,
          id: id,
          title: title,
          body: body,
          recordedAtMs: recordedAtMs,
        );
      } on Object {
        // Fall through to Dart log.
      }
    }
    return _log.append(
      kind: NoteOpKind.edit,
      id: id,
      title: title,
      body: body,
      recordedAtMs: recordedAtMs,
    );
  }

  Future<NotesOperation> deleteNote({
    required String id,
    required int recordedAtMs,
  }) async {
    if (_rustReady) {
      try {
        mindRuntimeDeleteNote(id: id, recordedAtMs: BigInt.from(recordedAtMs));
        return NotesOperation(
          seq: 0,
          kind: NoteOpKind.delete,
          id: id,
          title: '',
          body: '',
          recordedAtMs: recordedAtMs,
        );
      } on Object {
        // Fall through to Dart log.
      }
    }
    return _log.append(
      kind: NoteOpKind.delete,
      id: id,
      recordedAtMs: recordedAtMs,
    );
  }

  /// Reads the current projection. Always a fresh fold of the log -- never a
  /// cache this capability keeps itself, because keeping one would be
  /// exactly the durable state `C5` forbids it from owning.
  Future<NotesProjection> notes() async {
    if (_rustReady) {
      try {
        final raw = jsonDecode(mindRuntimeNotesJson()) as List<dynamic>;
        final ops = <NotesOperation>[];
        for (final entry in raw) {
          final map = entry as Map<String, dynamic>;
          ops.add(
            NotesOperation(
              seq: ops.length,
              kind: NoteOpKind.create,
              id: map['id'] as String? ?? '',
              title: map['title'] as String? ?? '',
              body: map['body'] as String? ?? '',
              recordedAtMs: (map['updatedAtMs'] as num?)?.toInt() ?? 0,
            ),
          );
        }
        return NotesProjection.rebuild(ops);
      } on Object {
        // Fall through to Dart log.
      }
    }
    return NotesProjection.rebuild(await _log.replay());
  }
}
