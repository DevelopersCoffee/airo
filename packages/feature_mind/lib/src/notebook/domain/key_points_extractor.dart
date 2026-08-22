/// Pulls key points out of minutes, action items, and transcript.
///
/// Prefers explicit bullets / numbered lists / action items over inventing
/// sentences. When none of those exist, falls back to the first few
/// transcript sentences so a recording still has something to scan.
class KeyPointsExtractor {
  const KeyPointsExtractor({this.limit = defaultLimit});

  static const defaultLimit = 12;

  final int limit;

  List<String> extract({
    String minutes = '',
    String transcript = '',
    List<String> actionItems = const [],
  }) {
    final collected = <String>[..._clean(actionItems), ..._bullets(minutes)];
    final unique = _dedupe(collected);
    if (unique.isNotEmpty) {
      return unique.take(limit).toList(growable: false);
    }
    final fallback = transcript.trim().isNotEmpty ? transcript : minutes;
    return _sentences(fallback).take(limit).toList(growable: false);
  }

  List<String> _bullets(String text) {
    final points = <String>[];
    var inKeySection = false;
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        inKeySection = false;
        continue;
      }
      if (_isKeyHeading(line)) {
        inKeySection = true;
        continue;
      }
      final bullet = _bulletText(line);
      if (bullet != null) {
        points.add(bullet);
        continue;
      }
      if (inKeySection && line.length >= 8 && !line.startsWith('#')) {
        points.add(line);
      }
    }
    return points;
  }

  bool _isKeyHeading(String line) {
    final stripped = line
        .replaceFirst(RegExp(r'^#+\s*'), '')
        .trim()
        .toLowerCase();
    return stripped == 'key points' ||
        stripped == 'key point' ||
        stripped == 'highlights' ||
        stripped == 'takeaways' ||
        stripped == 'action items' ||
        stripped == 'actions' ||
        stripped == 'सार' ||
        stripped == 'मुख्य बातें';
  }

  String? _bulletText(String line) {
    final match = RegExp(
      r'^(?:[-*•–]|\d+[.)]|\[\s*[xX ]\s*\])\s+(.+)$',
    ).firstMatch(line);
    if (match == null) return null;
    final text = match.group(1)!.trim();
    return text.length >= 3 ? text : null;
  }

  List<String> _sentences(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) return const [];
    final parts = compact
        .split(RegExp(r'(?<=[.!?।])\s+'))
        .map((part) => part.trim())
        .where((part) => part.length >= 12)
        .toList();
    return _dedupe(parts);
  }

  List<String> _clean(List<String> items) => [
    for (final item in items)
      if (item.trim().length >= 3) item.trim(),
  ];

  List<String> _dedupe(List<String> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in items) {
      final key = item.toLowerCase();
      if (seen.add(key)) out.add(item);
    }
    return out;
  }
}
