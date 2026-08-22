import 'source_normalizer.dart';

/// Durable research-library payload. Same v1 record as Rust.
class ResearchLibraryEntry {
  const ResearchLibraryEntry({
    required this.topicKey,
    required this.question,
    required this.retrievedAt,
    required this.sourceUrls,
    required this.findings,
  });

  factory ResearchLibraryEntry.fromQuestion({
    required String question,
    required String retrievedAt,
    required List<String> sourceUrls,
    required List<String> findings,
  }) {
    return ResearchLibraryEntry(
      topicKey: topicKeyFor(question),
      question: question.trim(),
      retrievedAt: retrievedAt,
      sourceUrls: sourceUrls.map(canonicalizeUrl).toList(growable: false),
      findings: findings,
    );
  }

  final String topicKey;
  final String question;
  final String retrievedAt;
  final List<String> sourceUrls;
  final List<String> findings;

  String toRecord() {
    return 'v1\u001f$topicKey\u001f$question\u001f$retrievedAt\u001f'
        '${sourceUrls.join(',')}\u001f${findings.join('||')}';
  }

  static ResearchLibraryEntry fromRecord(String record) {
    final parts = record.split('\u001f');
    if (parts.length != 6 || parts.first != 'v1') {
      throw const FormatException('invalid research library record');
    }
    return ResearchLibraryEntry(
      topicKey: parts[1],
      question: parts[2],
      retrievedAt: parts[3],
      sourceUrls: parts[4].isEmpty ? const [] : parts[4].split(','),
      findings: parts[5].isEmpty ? const [] : parts[5].split('||'),
    );
  }
}

String topicKeyFor(String question) {
  return question.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');
}

List<String> deltaUrls(List<String> previous, List<String> candidates) {
  final known = previous.map(canonicalizeUrl).toSet();
  return [
    for (final url in candidates)
      if (!known.contains(canonicalizeUrl(url))) canonicalizeUrl(url),
  ];
}
