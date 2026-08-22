import 'notebook_note.dart';

/// Keyword + tag + label + language filter over notebook notes.
///
/// Deliberately not semantic search — meetings already have that ranker.
/// Notes need something that works with no embedding model and stays honest
/// about tags the person actually set.
class NotebookSearch {
  const NotebookSearch();

  List<NotebookNote> filter({
    required List<NotebookNote> notes,
    String query = '',
    Set<String> tags = const {},
    Set<String> labels = const {},
    String? languageCode,
  }) {
    final needle = query.trim().toLowerCase();
    final tagNeedles = {for (final tag in tags) tag.trim().toLowerCase()}
      ..removeWhere((tag) => tag.isEmpty);
    final labelNeedles = {
      for (final label in labels) label.trim().toLowerCase(),
    }..removeWhere((label) => label.isEmpty);

    return [
      for (final note in notes)
        if (_matches(
          note,
          needle: needle,
          tags: tagNeedles,
          labels: labelNeedles,
          languageCode: languageCode,
        ))
          note,
    ];
  }

  bool _matches(
    NotebookNote note, {
    required String needle,
    required Set<String> tags,
    required Set<String> labels,
    required String? languageCode,
  }) {
    if (languageCode != null &&
        languageCode.isNotEmpty &&
        note.document.languageCode != languageCode) {
      return false;
    }
    if (tags.isNotEmpty) {
      final have = {for (final tag in note.document.tags) tag.toLowerCase()};
      if (!tags.every(have.contains)) return false;
    }
    if (labels.isNotEmpty) {
      final have = {
        for (final label in note.document.labels) label.toLowerCase(),
      };
      if (!labels.every(have.contains)) return false;
    }
    if (needle.isEmpty) return true;
    return _haystack(note).contains(needle);
  }

  String _haystack(NotebookNote note) {
    final doc = note.document;
    return [
      note.title,
      doc.body,
      doc.transcript,
      doc.summary,
      ...doc.keyPoints,
      ...doc.tags,
      ...doc.labels,
      doc.languageCode ?? '',
      doc.source.name,
    ].join('\n').toLowerCase();
  }
}
