import 'dart:convert';

/// Compact JSON and JSONL helpers for internal Airo storage (no pretty-print).
class CompactJsonl {
  const CompactJsonl._();

  /// Single-line JSON with no extra whitespace.
  static String encodeLine(Map<String, dynamic> value) =>
      jsonEncode(value);

  static Map<String, dynamic> decodeLine(String line) {
    final decoded = jsonDecode(line.trim());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSONL line must decode to a JSON object.');
    }
    return decoded;
  }

  static List<Map<String, dynamic>> parse(String raw) {
    if (raw.trim().isEmpty) return const [];
    final rows = <Map<String, dynamic>>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      rows.add(decodeLine(trimmed));
    }
    return rows;
  }

  static String encodeAll(List<Map<String, dynamic>> rows) =>
      rows.map(encodeLine).join('\n');
}

/// Compact JSON blob encoding for ephemeral caches (graphs, manifests).
String encodeCompactJson(Object? value) => jsonEncode(value);

Map<String, dynamic> decodeCompactJsonMap(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Compact JSON must decode to an object.');
  }
  return decoded;
}
