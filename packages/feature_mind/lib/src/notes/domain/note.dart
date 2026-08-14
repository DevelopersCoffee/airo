/// One note, as the projection holds it. `#1338`'s runtime skeleton.
///
/// Never constructed by hand outside [NotesOperationLog] replay -- the only
/// way a [Note] comes to exist in a [NotesProjection] is by folding operation
/// log entries. Mirrors `airo_mind_core::notes::Note` on the Rust side of the
/// vertical slice; see `rust/airo_mind_core/src/notes.rs` for the twin
/// implementation this one is deliberately kept in lockstep with.
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAtMs,
  });

  final String id;
  final String title;
  final String body;

  /// The operation's `recordedAtMs` at the time of the mutation that most
  /// recently touched this note. Supplied by the caller, never sampled from
  /// the wall clock on the replay path (`C2`).
  final int updatedAtMs;

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.updatedAtMs == updatedAtMs;

  @override
  int get hashCode => Object.hash(id, title, body, updatedAtMs);

  @override
  String toString() => 'Note($id, "$title", updatedAtMs: $updatedAtMs)';
}
