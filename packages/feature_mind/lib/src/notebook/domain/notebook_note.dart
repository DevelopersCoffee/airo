import '../../notes/domain/note.dart';
import 'notebook_document.dart';

/// A [Note] plus its decoded [NotebookDocument].
class NotebookNote {
  const NotebookNote({required this.note, required this.document});

  factory NotebookNote.fromNote(Note note) =>
      NotebookNote(note: note, document: NotebookDocument.decode(note.body));

  final Note note;
  final NotebookDocument document;

  String get id => note.id;
  String get title => note.title;
  int get updatedAtMs => note.updatedAtMs;
  String get preview => document.preview;
}
