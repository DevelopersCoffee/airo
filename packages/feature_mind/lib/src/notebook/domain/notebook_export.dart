import 'notebook_note.dart';
import 'notebook_source.dart';

/// Markdown for one notebook note — the export / copy / share payload.
String renderNotebookMarkdown(NotebookNote note) {
  final doc = note.document;
  final recorded = DateTime.fromMillisecondsSinceEpoch(
    note.updatedAtMs,
    isUtc: true,
  );
  final buf = StringBuffer()
    ..writeln('---')
    ..writeln('title: "${_escapeYaml(note.title)}"')
    ..writeln('date: ${recorded.toIso8601String()}')
    ..writeln('source: ${doc.source.name}');
  if (doc.languageCode != null && doc.languageCode!.isNotEmpty) {
    buf.writeln('language: ${doc.languageCode}');
  }
  if (doc.tags.isNotEmpty) {
    buf.writeln('tags: [${doc.tags.map(_escapeYaml).join(', ')}]');
  }
  if (doc.labels.isNotEmpty) {
    buf.writeln('labels: [${doc.labels.map(_escapeYaml).join(', ')}]');
  }
  if (doc.source == NotebookSource.superSummary &&
      doc.sourceNoteIds.isNotEmpty) {
    buf.writeln('folded_from: [${doc.sourceNoteIds.join(', ')}]');
  }
  buf.writeln('---');
  buf.writeln();
  buf.writeln('# ${note.title}');
  buf.writeln();

  if (doc.summary.trim().isNotEmpty) {
    buf.writeln('## Summary');
    buf.writeln();
    buf.writeln(doc.summary.trim());
    buf.writeln();
  }
  if (doc.keyPoints.isNotEmpty) {
    buf.writeln('## Key points');
    buf.writeln();
    for (final point in doc.keyPoints) {
      buf.writeln('- $point');
    }
    buf.writeln();
  }
  if (doc.body.trim().isNotEmpty) {
    buf.writeln('## Notes');
    buf.writeln();
    buf.writeln(doc.body.trim());
    buf.writeln();
  }
  if (doc.transcript.trim().isNotEmpty) {
    buf.writeln('## Transcript');
    buf.writeln();
    buf.writeln(doc.transcript.trim());
    buf.writeln();
  }
  return '${buf.toString().trimRight()}\n';
}

String notebookExportFileName(NotebookNote note) {
  final slug = note.title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final safe = slug.isEmpty ? note.id : slug;
  return '$safe.md';
}

String _escapeYaml(String value) =>
    value.replaceAll('\\', r'\\').replaceAll('"', r'\"');
