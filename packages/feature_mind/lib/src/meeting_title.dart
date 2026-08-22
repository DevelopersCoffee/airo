/// Titles stored as `Meeting 4` or `Meeting 2026-08-23 03:01:00.086253` —
/// placeholders the capture path used before it had a transcript to name
/// the conversation from.
bool isGenericMeetingTitle(String title) {
  final trimmed = title.trim();
  if (RegExp(r'^Meeting(\s+\d+)?$').hasMatch(trimmed)) return true;
  return RegExp(r'^Meeting\s+\d{4}-\d{2}-\d{2}').hasMatch(trimmed);
}

/// A short, identifiable name from what was said.
///
/// Deterministic and local — no extra model pass. Prefers a named speaker
/// plus the first content sentence so a career intro becomes
/// `Quintang — PhD in Chinese Academy of Science` rather than a timestamp.
String meetingTitleFromTranscript(String transcript) {
  final text = _flattenTranscript(transcript);
  if (text.length < 12) return 'Conversation';

  final name = _introducedName(text);
  String? topic;
  for (final sentence in _sentences(text)) {
    if (_isWeakSentence(sentence)) continue;
    topic = _clipTitle(_stripLeadIn(sentence), 56);
    break;
  }
  topic ??= _clipTitle(text, 56);

  if (name != null && !topic.toLowerCase().contains(name.toLowerCase())) {
    return _clipTitle('$name — $topic', 64);
  }
  return topic;
}

/// [requested] unless it is a placeholder and the transcript can do better.
String resolveMeetingTitle({
  required String requested,
  required String transcript,
}) {
  if (!isGenericMeetingTitle(requested)) return requested.trim();
  final derived = meetingTitleFromTranscript(transcript);
  return derived;
}

String displayMeetingTitle({
  required String title,
  required String transcript,
}) {
  if (!isGenericMeetingTitle(title)) return title.trim();
  if (transcript.trim().isEmpty) return title.trim();
  return meetingTitleFromTranscript(transcript);
}

String _flattenTranscript(String raw) {
  return raw
      .replaceAll(RegExp(r'\[\d{2}:\d{2}:\d{2}\]'), ' ')
      .replaceAll(RegExp(r'\bsp\d+:\s*'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> _sentences(String text) {
  return text
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

String? _introducedName(String text) {
  final match = RegExp(
    r"(?:my name is|i am|i'm)\s+([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+)?)",
    caseSensitive: false,
  ).firstMatch(text);
  final raw = match?.group(1)?.trim();
  if (raw == null || raw.length < 2) return null;
  return raw
      .split(RegExp(r'\s+'))
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

bool _isWeakSentence(String sentence) {
  final words = sentence.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.length < 5) return true;
  if (RegExp(
    r"(?:my name is|i am|i'm)\s+\w+",
    caseSensitive: false,
  ).hasMatch(sentence)) {
    return words.length < 14;
  }
  return false;
}

String _stripLeadIn(String sentence) {
  return sentence
      .replaceFirst(
        RegExp(
          r'^(so|and|um|uh|well|okay|yes|yeah)[,.]?\s+',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
}

String _clipTitle(String text, int max) {
  var cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  cleaned = cleaned.replaceFirst(RegExp(r'[.?!,:;]+$'), '');
  if (cleaned.length <= max) return cleaned;
  final slice = cleaned.substring(0, max);
  final cut = slice.lastIndexOf(' ');
  return '${(cut > 24 ? slice.substring(0, cut) : slice).trimRight()}…';
}
