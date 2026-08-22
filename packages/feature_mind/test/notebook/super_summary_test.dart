import 'package:feature_mind/src/notebook/domain/notebook_document.dart';
import 'package:feature_mind/src/notebook/domain/notebook_note.dart';
import 'package:feature_mind/src/notebook/domain/super_summary.dart';
import 'package:feature_mind/src/notes/domain/note.dart';
import 'package:flutter_test/flutter_test.dart';

NotebookNote _note({
  required String id,
  required String title,
  NotebookDocument document = const NotebookDocument(),
}) {
  return NotebookNote(
    note: Note(id: id, title: title, body: document.encode(), updatedAtMs: 1),
    document: document,
  );
}

void main() {
  const composer = SuperSummaryComposer();

  test('extractive Super Summary merges key points, tags, and titles', () {
    final a = _note(
      id: 'a',
      title: 'Standup',
      document: const NotebookDocument(
        summary: 'Ship Friday.',
        keyPoints: ['Ship Friday'],
        tags: ['work'],
        transcript: 'We ship Friday.',
      ),
    );
    final b = _note(
      id: 'b',
      title: 'Lecture',
      document: const NotebookDocument(
        summary: 'Gradient descent recap.',
        keyPoints: ['Use a smaller learning rate'],
        tags: ['study'],
        languageCode: 'en',
      ),
    );

    final recap = composer.compose(notes: [a, b]);

    expect(recap.source.name, 'superSummary');
    expect(recap.sourceNoteIds, ['a', 'b']);
    expect(recap.tags, containsAll(['work', 'study']));
    expect(recap.labels, contains('super-summary'));
    expect(recap.summary, contains('Standup'));
    expect(recap.summary, contains('Lecture'));
    expect(recap.keyPoints, contains('Ship Friday'));
    expect(recap.keyPoints, contains('Use a smaller learning rate'));
    expect(composer.defaultTitle([a, b]), 'Super summary · 2 notes');
  });

  test('generated recap wins over extractive summary', () {
    final notes = [
      _note(
        id: 'a',
        title: 'One',
        document: const NotebookDocument(body: 'aaa'),
      ),
      _note(
        id: 'b',
        title: 'Two',
        document: const NotebookDocument(body: 'bbb'),
      ),
    ];

    final recap = composer.compose(
      notes: notes,
      generatedRecap: '''
# Summary
Both threads agree to delay the launch.

# Key points
- Delay the launch
- Tell the customer first
''',
    );

    expect(recap.summary, contains('delay the launch'));
    expect(recap.keyPoints.first, contains('Delay the launch'));
  });
}
