import 'package:feature_mind/src/notebook/domain/notebook_document.dart';
import 'package:feature_mind/src/notebook/domain/notebook_note.dart';
import 'package:feature_mind/src/notebook/domain/notebook_search.dart';
import 'package:feature_mind/src/notes/domain/note.dart';
import 'package:flutter_test/flutter_test.dart';

NotebookNote _note({
  required String id,
  required String title,
  NotebookDocument? document,
  String body = '',
}) {
  final doc = document ?? NotebookDocument(body: body);
  return NotebookNote(
    note: Note(id: id, title: title, body: doc.encode(), updatedAtMs: 1),
    document: doc,
  );
}

void main() {
  const search = NotebookSearch();

  final notes = [
    _note(
      id: '1',
      title: 'Standup',
      document: const NotebookDocument(
        body: 'pods',
        tags: ['work'],
        labels: ['meeting'],
        languageCode: 'en',
        summary: 'Adopt Kubernetes',
      ),
    ),
    _note(
      id: '2',
      title: 'Lecture',
      document: const NotebookDocument(
        transcript: 'backpropagation',
        tags: ['study'],
        languageCode: 'hi',
      ),
    ),
  ];

  test('query matches title, summary, tags, and transcript', () {
    expect(search.filter(notes: notes, query: 'kubernetes').single.id, '1');
    expect(search.filter(notes: notes, query: 'backprop').single.id, '2');
    expect(search.filter(notes: notes, query: 'work').single.id, '1');
  });

  test('tag, label, and language filters are conjunctive', () {
    expect(
      search
          .filter(notes: notes, tags: {'work'}, labels: {'meeting'})
          .single
          .id,
      '1',
    );
    expect(search.filter(notes: notes, languageCode: 'hi').single.id, '2');
    expect(
      search.filter(notes: notes, tags: {'work'}, languageCode: 'hi'),
      isEmpty,
    );
  });
}
