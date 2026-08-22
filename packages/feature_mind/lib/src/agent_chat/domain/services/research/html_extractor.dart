import 'research_search.dart';

/// Main-content extraction. Retrieved HTML is untrusted evidence, never
/// instructions. Do not send the raw page to a model.
class ExtractedHtml {
  const ExtractedHtml({
    required this.title,
    required this.headings,
    required this.paragraphs,
    required this.tables,
    required this.codeBlocks,
    this.publishedAt,
    this.trustLevel = SourceTrust.untrusted,
  });

  final String title;
  final List<String> headings;
  final List<String> paragraphs;
  final List<String> tables;
  final List<String> codeBlocks;
  final String? publishedAt;
  final SourceTrust trustLevel;

  String get evidenceText => [...headings, ...paragraphs, ...tables].join(' ');
}

/// Top-level so large pages can run through [runOffMain].
ExtractedHtml extractHtml(String html) {
  var body = _stripBlocks(html, const [
    'script',
    'style',
    'noscript',
    'nav',
    'footer',
    'header',
    'aside',
  ]);
  body = _stripComments(body);
  final title = _firstInner(body, 'title') ?? _firstInner(body, 'h1') ?? '';
  final headings = [
    ..._allInner(body, 'h1'),
    ..._allInner(body, 'h2'),
    ..._allInner(body, 'h3'),
  ];
  final paragraphs = _allInner(body, 'p');
  final tables = _tableRows(body);
  final codeBlocks = [..._allInner(body, 'pre'), ..._allInner(body, 'code')];
  return ExtractedHtml(
    title: title,
    headings: _unique(headings),
    paragraphs: _unique(paragraphs),
    tables: _unique(tables),
    codeBlocks: _unique(codeBlocks),
    publishedAt: _publishedAt(html),
  );
}

String _stripBlocks(String html, List<String> tags) {
  var out = html;
  for (final tag in tags) {
    out = out.replaceAll(
      RegExp('<$tag\\b[^>]*>[\\s\\S]*?</$tag>', caseSensitive: false),
      ' ',
    );
  }
  return out;
}

String _stripComments(String html) {
  return html.replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ');
}

String? _firstInner(String html, String tag) {
  final all = _allInner(html, tag);
  return all.isEmpty ? null : all.first;
}

List<String> _tableRows(String html) {
  final out = <String>[];
  final tables = RegExp(
    r'<table\b[^>]*>([\s\S]*?)</table>',
    caseSensitive: false,
  ).allMatches(html);
  for (final table in tables) {
    final rows = RegExp(
      r'<tr\b[^>]*>([\s\S]*?)</tr>',
      caseSensitive: false,
    ).allMatches(table.group(1) ?? '');
    for (final row in rows) {
      final cells =
          RegExp(r'<t[dh]\b[^>]*>([\s\S]*?)</t[dh]>', caseSensitive: false)
              .allMatches(row.group(1) ?? '')
              .map((match) => _visibleText(match.group(1) ?? ''))
              .where((cell) => cell.isNotEmpty)
              .toList(growable: false);
      if (cells.length >= 2) {
        out.add(cells.join(' | '));
      }
    }
  }
  return _unique(out);
}

List<String> _allInner(String html, String tag) {
  final matches = RegExp(
    '<$tag\\b[^>]*>([\\s\\S]*?)</$tag>',
    caseSensitive: false,
  ).allMatches(html);
  return matches
      .map((match) => _visibleText(match.group(1) ?? ''))
      .where((text) => text.length >= 2)
      .toList(growable: false);
}

String _visibleText(String raw) {
  return _decode(
    raw.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' '),
  ).trim();
}

String _decode(String raw) {
  return raw
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

String? _publishedAt(String html) {
  final propertyThenContent = RegExp(
    r'''<meta[^>]+property=["']article:published_time["'][^>]+content=["']([^"']+)["']''',
    caseSensitive: false,
  ).firstMatch(html);
  if (propertyThenContent != null) {
    return propertyThenContent.group(1);
  }
  final contentThenProperty = RegExp(
    r'''<meta[^>]+content=["']([^"']+)["'][^>]+property=["']article:published_time["']''',
    caseSensitive: false,
  ).firstMatch(html);
  return contentThenProperty?.group(1);
}

List<String> _unique(List<String> items) {
  final seen = <String>{};
  final out = <String>[];
  for (final item in items) {
    if (seen.add(item)) {
      out.add(item);
    }
  }
  return out;
}
