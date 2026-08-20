import 'package:feature_mind/src/notebook/domain/notebook_document.dart';
import 'package:feature_mind/src/notebook/domain/notebook_export.dart';
import 'package:feature_mind/src/notebook/domain/notebook_l10n.dart';
import 'package:feature_mind/src/notebook/domain/notebook_note.dart';
import 'package:feature_mind/src/notebook/domain/notebook_source.dart';
import 'package:feature_mind/src/notes/domain/note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'markdown export includes summary, key points, tags, and transcript',
    () {
      final note = NotebookNote(
        note: const Note(
          id: 'n1',
          title: 'Standup',
          body: '',
          updatedAtMs: 1_700_000_000_000,
        ),
        document: const NotebookDocument(
          body: 'follow up with Priya',
          transcript: 'We ship Friday.',
          summary: 'Ship Friday.',
          keyPoints: ['Ship Friday'],
          tags: ['work'],
          labels: ['meeting'],
          languageCode: 'en',
          source: NotebookSource.live,
        ),
      );

      final md = renderNotebookMarkdown(note);
      expect(md, contains('title: "Standup"'));
      expect(md, contains('tags: [work]'));
      expect(md, contains('## Summary'));
      expect(md, contains('## Key points'));
      expect(md, contains('- Ship Friday'));
      expect(md, contains('## Transcript'));
      expect(notebookExportFileName(note), 'standup.md');
    },
  );

  test('notebook UI copy is localized and falls back to English', () {
    expect(NotebookL10n.of('en').noNotesYet, 'No notes yet');
    expect(NotebookL10n.of('hi').noNotesYet, isNot('No notes yet'));
    expect(NotebookL10n.of('hi').notesTitle, 'नोट्स');
    expect(NotebookL10n.of('es').share, 'Compartir');
    expect(NotebookL10n.of('ar').superSummary, isNotEmpty);
    expect(NotebookL10n.of('xx-ZZ').locale, 'en');
    expect(NotebookL10n.of('pt-BR').locale, 'pt');
  });
}
