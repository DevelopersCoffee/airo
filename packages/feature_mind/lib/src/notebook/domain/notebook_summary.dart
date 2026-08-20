/// First-paragraph / named-section summary of minutes or a transcript.
class NotebookSummary {
  static const maxChars = 600;

  /// Prefer an explicit Summary / Overview / Recap section; otherwise the
  /// first paragraph, clipped so a list row stays readable.
  static String fromMinutes(String minutes) {
    final trimmed = minutes.trim();
    if (trimmed.isEmpty) return '';
    final section = _namedSection(trimmed, const [
      'summary',
      'overview',
      'recap',
      'abstract',
      'सारांश',
      'सार',
    ]);
    if (section != null && section.isNotEmpty) return _clip(section);
    final paragraph = trimmed.split(RegExp(r'\n\s*\n')).first.trim();
    return _clip(paragraph);
  }

  static String? _namedSection(String text, List<String> headings) {
    final lines = text.split('\n');
    final wanted = headings.map((h) => h.toLowerCase()).toSet();
    final buf = StringBuffer();
    var capturing = false;
    for (final raw in lines) {
      final line = raw.trim();
      final heading = line.replaceFirst(RegExp(r'^#+\s*'), '').toLowerCase();
      if (wanted.contains(heading)) {
        if (capturing) break;
        capturing = true;
        continue;
      }
      if (capturing) {
        if (line.startsWith('#') && line.length < 80) break;
        if (buf.isNotEmpty) buf.writeln();
        buf.write(raw);
      }
    }
    final captured = buf.toString().trim();
    return captured.isEmpty ? null : captured;
  }

  static String _clip(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxChars) return compact;
    return '${compact.substring(0, maxChars).trimRight()}…';
  }
}
