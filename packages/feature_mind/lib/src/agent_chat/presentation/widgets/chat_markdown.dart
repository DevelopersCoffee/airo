import 'package:flutter/painting.dart';

/// Turns common chat Markdown into [InlineSpan]s without a Markdown package.
///
/// Small GGUF models emit `**Heading**` instead of `# Heading`. The chat
/// bubble used to show the asterisks as literal text.
List<InlineSpan> chatMarkdownSpans(String text, {required TextStyle style}) {
  final normalized = _normalizeLineMarkup(text);
  if (normalized.isEmpty) return const [];

  final bold = style.copyWith(fontWeight: FontWeight.w700);
  final italic = style.copyWith(fontStyle: FontStyle.italic);
  final code = style.copyWith(
    fontFamily: 'monospace',
    fontSize: (style.fontSize ?? 14) * 0.92,
  );

  final pattern = RegExp(
    r'\*\*(.+?)\*\*'
    r'|\*(?!\*)(.+?)\*(?!\*)'
    r'|__(.+?)__'
    r'|(?<![A-Za-z0-9_])_([^_\n]+?)_(?![A-Za-z0-9_])'
    r'|`([^`]+)`',
  );

  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final match in pattern.allMatches(normalized)) {
    if (match.start > cursor) {
      spans.add(
        TextSpan(text: normalized.substring(cursor, match.start), style: style),
      );
    }
    if (match.group(1) != null) {
      spans.add(TextSpan(text: match.group(1), style: bold));
    } else if (match.group(2) != null) {
      spans.add(TextSpan(text: match.group(2), style: italic));
    } else if (match.group(3) != null) {
      spans.add(TextSpan(text: match.group(3), style: bold));
    } else if (match.group(4) != null) {
      spans.add(TextSpan(text: match.group(4), style: italic));
    } else if (match.group(5) != null) {
      spans.add(TextSpan(text: match.group(5), style: code));
    }
    cursor = match.end;
  }
  if (cursor < normalized.length) {
    spans.add(TextSpan(text: normalized.substring(cursor), style: style));
  }
  return spans;
}

/// Visible characters after Markdown markers are applied.
String chatMarkdownPlainText(String text) {
  return TextSpan(
    children: chatMarkdownSpans(text, style: const TextStyle()),
  ).toPlainText();
}

String _normalizeLineMarkup(String text) {
  var result = text.replaceAllMapped(
    RegExp(r'^#{1,3}\s+(.+)$', multiLine: true),
    (match) => '**${match[1]}**',
  );
  result = result.replaceAllMapped(
    RegExp(r'^[\*\-]\s+', multiLine: true),
    (_) => '• ',
  );
  return result;
}
