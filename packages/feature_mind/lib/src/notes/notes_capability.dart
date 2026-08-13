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
class NotesCapability {
  const NotesCapability(this._log);

  final NotesOperationLog _log;

  /// Emits a `create` operation. The only way a note comes into existence --
  /// there is no direct write path to [NotesProjection].
  Future<NotesOperation> createNote({
    required String id,
    required String title,
    required String body,
    required int recordedAtMs,
  }) => _log.append(
    kind: NoteOpKind.create,
    id: id,
    title: title,
    body: body,
    recordedAtMs: recordedAtMs,
  );

  Future<NotesOperation> editNote({
    required String id,
    required String title,
    required String body,
    required int recordedAtMs,
  }) => _log.append(
    kind: NoteOpKind.edit,
    id: id,
    title: title,
    body: body,
    recordedAtMs: recordedAtMs,
  );

  Future<NotesOperation> deleteNote({
    required String id,
    required int recordedAtMs,
  }) =>
      _log.append(kind: NoteOpKind.delete, id: id, recordedAtMs: recordedAtMs);

  /// Reads the current projection. Always a fresh fold of the log -- never a
  /// cache this capability keeps itself, because keeping one would be
  /// exactly the durable state `C5` forbids it from owning.
  Future<NotesProjection> notes() async =>
      NotesProjection.rebuild(await _log.replay());
}
