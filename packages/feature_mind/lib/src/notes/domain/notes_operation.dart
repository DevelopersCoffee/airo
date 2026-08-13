/// What a Notes operation records. Closed set, matching
/// `airo_mind_core::notes`'s `note.create` / `note.edit` / `note.delete`
/// kinds -- a capability's vocabulary is opaque to the runtime (`C5`), but it
/// is not arbitrary: this is the entire set of things Notes can cause to be
/// durable.
enum NoteOpKind {
  create,
  edit,
  delete;

  String get wireName => switch (this) {
    NoteOpKind.create => 'create',
    NoteOpKind.edit => 'edit',
    NoteOpKind.delete => 'delete',
  };

  static NoteOpKind fromWireName(String name) => switch (name) {
    'create' => NoteOpKind.create,
    'edit' => NoteOpKind.edit,
    'delete' => NoteOpKind.delete,
    _ => throw FormatException('unknown note operation kind: $name'),
  };
}

/// One durable entry in the Notes operation log.
///
/// The beginning of the operation log condition (`#1194`) at skeleton scale:
/// a minimal, local, unsigned record -- not the signed, synced log Phase 2
/// builds. What it proves is the shape everything after it depends on: a
/// capability's mutation becomes one immutable, ordered, replayable fact.
class NotesOperation {
  const NotesOperation({
    required this.seq,
    required this.kind,
    required this.id,
    required this.title,
    required this.body,
    required this.recordedAtMs,
  });

  /// Monotonic, gap-free, assigned by [NotesOperationLog.append].
  final int seq;
  final NoteOpKind kind;

  /// The note this operation is about. Empty title/body are valid for
  /// [NoteOpKind.delete], which carries only [id].
  final String id;
  final String title;
  final String body;

  /// Supplied by the caller, never sampled from the wall clock inside the
  /// log (`C2`'s determinism discipline, kept even though this Dart log is
  /// not yet on a byte-identical-replay path shared across devices).
  final int recordedAtMs;

  Map<String, Object?> toJson() => {
    'seq': seq,
    'kind': kind.wireName,
    'id': id,
    'title': title,
    'body': body,
    'recordedAtMs': recordedAtMs,
  };

  factory NotesOperation.fromJson(Map<String, Object?> json) => NotesOperation(
    seq: json['seq']! as int,
    kind: NoteOpKind.fromWireName(json['kind']! as String),
    id: json['id']! as String,
    title: json['title']! as String,
    body: json['body']! as String,
    recordedAtMs: json['recordedAtMs']! as int,
  );

  @override
  bool operator ==(Object other) =>
      other is NotesOperation &&
      other.seq == seq &&
      other.kind == kind &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.recordedAtMs == recordedAtMs;

  @override
  int get hashCode => Object.hash(seq, kind, id, title, body, recordedAtMs);
}
