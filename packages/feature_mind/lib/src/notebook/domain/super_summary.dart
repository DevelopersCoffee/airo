import 'key_points_extractor.dart';
import 'notebook_document.dart';
import 'notebook_note.dart';
import 'notebook_source.dart';
import 'notebook_summary.dart';

/// Folds several notebook notes into one Super Summary document.
///
/// When [generatedRecap] is supplied (on-device LLM), that text is the
/// summary and its bullets become key points. Otherwise the composer builds
/// a deterministic extractive recap so Super Summary still works with no
/// model loaded.
class SuperSummaryComposer {
  const SuperSummaryComposer({this.extractor = const KeyPointsExtractor()});

  final KeyPointsExtractor extractor;

  NotebookDocument compose({
    required List<NotebookNote> notes,
    String? generatedRecap,
  }) {
    if (notes.isEmpty) {
      throw ArgumentError('Super Summary needs at least one note');
    }
    final tags = _unique([for (final note in notes) ...note.document.tags]);
    final labels = _unique([
      for (final note in notes) ...note.document.labels,
      'super-summary',
    ]);
    final mergedPoints = extractor.extract(
      minutes: [
        for (final note in notes)
          if (note.document.summary.isNotEmpty) note.document.summary,
        for (final note in notes) ...note.document.keyPoints,
      ].join('\n- '),
      transcript: [
        for (final note in notes)
          if (note.document.transcript.isNotEmpty) note.document.transcript,
      ].join('\n\n'),
      actionItems: [for (final note in notes) ...note.document.keyPoints],
    );
    final extractiveSummary = _extractiveSummary(notes);
    final recap = generatedRecap?.trim();
    final summary = (recap != null && recap.isNotEmpty)
        ? NotebookSummary.fromMinutes(recap)
        : extractiveSummary;
    final recapPoints = recap == null || recap.isEmpty
        ? const <String>[]
        : extractor.extract(minutes: recap);
    final keyPoints = recapPoints.isNotEmpty ? recapPoints : mergedPoints;
    final language = _sharedLanguage(notes);

    return NotebookDocument(
      body: _sourceIndex(notes),
      transcript: [
        for (final note in notes)
          if (note.document.transcript.trim().isNotEmpty)
            '### ${note.title}\n${note.document.transcript.trim()}',
      ].join('\n\n'),
      summary: summary,
      keyPoints: keyPoints,
      tags: tags,
      labels: labels,
      languageCode: language,
      source: NotebookSource.superSummary,
      sourceNoteIds: [for (final note in notes) note.id],
    );
  }

  String defaultTitle(List<NotebookNote> notes) {
    if (notes.length == 1) return 'Super summary · ${notes.single.title}';
    return 'Super summary · ${notes.length} notes';
  }

  String _extractiveSummary(List<NotebookNote> notes) {
    final parts = <String>[
      'Combined recap of ${notes.length} notes: '
          '${notes.map((n) => n.title).join(', ')}.',
      for (final note in notes)
        if (note.document.summary.trim().isNotEmpty)
          '${note.title}: ${note.document.summary.trim()}',
    ];
    if (parts.length == 1) {
      for (final note in notes) {
        final preview = note.preview;
        if (preview.isNotEmpty) {
          parts.add('${note.title}: ${NotebookSummary.fromMinutes(preview)}');
        }
      }
    }
    return NotebookSummary.fromMinutes(parts.join('\n\n'));
  }

  String _sourceIndex(List<NotebookNote> notes) {
    final buf = StringBuffer('Folded from:\n');
    for (final note in notes) {
      buf.writeln('- ${note.title}');
    }
    return buf.toString().trimRight();
  }

  String? _sharedLanguage(List<NotebookNote> notes) {
    final codes = {
      for (final note in notes)
        if (note.document.languageCode != null) note.document.languageCode!,
    };
    if (codes.length == 1) return codes.single;
    return null;
  }

  List<String> _unique(List<String> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed.toLowerCase())) out.add(trimmed);
    }
    return out;
  }
}
