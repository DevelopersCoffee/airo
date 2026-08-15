import 'dart:collection';

import 'note.dart';
import 'notes_operation.dart';

/// The Notes read-model. `C4`: cache-only, rebuildable, disposable -- never
/// written to directly, only ever produced by [NotesProjection.rebuild]
/// folding the log.
///
/// Backed by a [SplayTreeMap] (ordered by key), not a [Map] built from hash
/// iteration -- the same discipline `airo_mind_core::notes::NotesProjection`
/// applies with `BTreeMap` on the Rust side (`C2` forbids `HashMap`
/// iteration on a path whose output must be compared for equality
/// deterministically).
class NotesProjection {
  NotesProjection._(this._notes);

  /// Folds the log in one pass, in order. `replay_passes == 1` (`C2`): one
  /// `for` loop over [ops], each operation visited exactly once.
  factory NotesProjection.rebuild(List<NotesOperation> ops) {
    final notes = SplayTreeMap<String, Note>();
    for (final op in ops) {
      switch (op.kind) {
        case NoteOpKind.create:
        case NoteOpKind.edit:
          notes[op.id] = Note(
            id: op.id,
            title: op.title,
            body: op.body,
            updatedAtMs: op.recordedAtMs,
          );
        case NoteOpKind.delete:
          notes.remove(op.id);
      }
    }
    return NotesProjection._(notes);
  }

  static final NotesProjection empty = NotesProjection.rebuild(const []);

  final SplayTreeMap<String, Note> _notes;

  Note? get(String id) => _notes[id];

  /// Every note, ordered by id -- deterministic, matching what the
  /// `SplayTreeMap` already gives for free.
  List<Note> get all => List.unmodifiable(_notes.values);

  int get length => _notes.length;

  bool get isEmpty => _notes.isEmpty;

  @override
  bool operator ==(Object other) {
    if (other is! NotesProjection) return false;
    if (other._notes.length != _notes.length) return false;
    for (final entry in _notes.entries) {
      if (other._notes[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    _notes.entries.map((e) => Object.hash(e.key, e.value)),
  );
}
