import 'html_extractor.dart';

/// Dispatch raw acquired bytes to the right extractor. Never dump a whole
/// page, PDF, or source file into the model as one blob.
ExtractedHtml extractDocument(String raw, {String? url}) {
  final hint = (url ?? '').toLowerCase();
  final trimmed = raw.trimLeft();
  if (trimmed.startsWith('%PDF') || hint.contains('.pdf')) {
    return extractPdf(raw);
  }
  if (_looksLikeHtml(raw)) {
    return extractHtml(raw);
  }
  if (hint.endsWith('.md') || _looksLikeMarkdown(raw)) {
    return extractMarkdown(raw);
  }
  return extractMarkdown(raw);
}

/// Uncompressed PDF text operators only. Scanned pages stay empty evidence.
ExtractedHtml extractPdf(String raw) {
  final paragraphs = <String>[];
  for (final match in RegExp(r'\((?:\\.|[^\\)]){8,400}\)').allMatches(raw)) {
    final wrapped = match.group(0)!;
    final text = _pdfUnescape(wrapped.substring(1, wrapped.length - 1)).trim();
    if (_looksLikeProse(text)) {
      paragraphs.add(text);
    }
  }
  return ExtractedHtml(
    title: paragraphs.isEmpty ? '' : paragraphs.first,
    headings: const [],
    paragraphs: _dedupe(paragraphs),
    tables: const [],
    codeBlocks: const [],
  );
}

ExtractedHtml extractMarkdown(String raw) {
  final codeBlocks = <String>[];
  final withoutCode = raw.replaceAllMapped(
    RegExp(r'```[A-Za-z0-9_-]*\n([\s\S]*?)```'),
    (match) {
      final code = (match.group(1) ?? '').trim();
      if (code.length >= 2) {
        codeBlocks.add(code);
      }
      return '\n';
    },
  );
  final headings = <String>[];
  final paragraphs = <String>[];
  final tables = <String>[];
  String title = '';
  for (final line in withoutCode.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    if (trimmed.startsWith('#')) {
      final heading = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
      if (heading.isEmpty) {
        continue;
      }
      headings.add(heading);
      title = title.isEmpty ? heading : title;
      continue;
    }
    if (trimmed.contains('|')) {
      final cells = trimmed
          .split('|')
          .map((cell) => cell.trim())
          .where((cell) => cell.isNotEmpty)
          .toList(growable: false);
      if (cells.length >= 2 &&
          !cells.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell))) {
        tables.add(cells.join(' | '));
      }
      continue;
    }
    if (trimmed.length >= 2) {
      paragraphs.add(trimmed);
    }
  }
  return ExtractedHtml(
    title: title,
    headings: _dedupe(headings),
    paragraphs: _dedupe(paragraphs),
    tables: _dedupe(tables),
    codeBlocks: _dedupe(codeBlocks),
  );
}

bool _looksLikeHtml(String raw) {
  return RegExp(
    r'<(html|body|article|p|table|h1|div)\b',
    caseSensitive: false,
  ).hasMatch(raw);
}

bool _looksLikeMarkdown(String raw) {
  return raw.contains('```') ||
      RegExp(r'^\s{0,3}#{1,6}\s', multiLine: true).hasMatch(raw) ||
      raw.contains('| ---');
}

bool _looksLikeProse(String text) {
  final letters = text.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.length < 8) {
    return false;
  }
  return letters.length / text.length >= 0.4;
}

String _pdfUnescape(String raw) {
  return raw
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\t', '\t')
      .replaceAll(r'\(', '(')
      .replaceAll(r'\)', ')')
      .replaceAll(r'\\', r'\');
}

List<String> _dedupe(List<String> items) {
  final seen = <String>{};
  final out = <String>[];
  for (final item in items) {
    if (seen.add(item)) {
      out.add(item);
    }
  }
  return out;
}
