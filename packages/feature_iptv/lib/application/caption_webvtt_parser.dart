class CaptionCue {
  const CaptionCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;
}

/// Parses a subset of WebVTT sufficient for sidecar `.vtt` files.
List<CaptionCue> parseWebVtt(String content) {
  final normalized = content.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) return const [];

  final lines = normalized.split('\n');
  var index = 0;
  if (lines[index].startsWith('\uFEFF')) {
    lines[index] = lines[index].substring(1);
  }
  if (lines[index].trim() == 'WEBVTT') {
    index++;
  }

  final cues = <CaptionCue>[];
  while (index < lines.length) {
    while (index < lines.length && lines[index].trim().isEmpty) {
      index++;
    }
    if (index >= lines.length) break;

    var timingLine = lines[index].trim();
    if (!timingLine.contains('-->')) {
      index++;
      if (index >= lines.length) break;
      timingLine = lines[index].trim();
    }
    if (!timingLine.contains('-->')) {
      index++;
      continue;
    }
    index++;

    final parts = timingLine.split('-->');
    if (parts.length != 2) continue;
    final start = _parseTimestamp(parts[0].trim());
    final end = _parseTimestamp(parts[1].trim().split(' ').first);
    if (start == null || end == null) continue;

    final buffer = <String>[];
    while (index < lines.length && lines[index].trim().isNotEmpty) {
      buffer.add(lines[index].trim());
      index++;
    }
    if (buffer.isEmpty) continue;
    cues.add(CaptionCue(start: start, end: end, text: buffer.join('\n')));
  }
  return cues;
}

CaptionCue? captionCueAt(List<CaptionCue> cues, Duration position) {
  for (final cue in cues) {
    if (position >= cue.start && position < cue.end) return cue;
  }
  return null;
}

Duration? _parseTimestamp(String value) {
  final segments = value.split(':');
  if (segments.length < 2) return null;
  try {
    if (segments.length == 2) {
      final minutes = int.parse(segments[0]);
      final secondsParts = segments[1].split('.');
      final seconds = int.parse(secondsParts[0]);
      final millis = secondsParts.length > 1
          ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
          : 0;
      return Duration(minutes: minutes, seconds: seconds, milliseconds: millis);
    }
    final hours = int.parse(segments[0]);
    final minutes = int.parse(segments[1]);
    final secondsParts = segments[2].split('.');
    final seconds = int.parse(secondsParts[0]);
    final millis = secondsParts.length > 1
        ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
        : 0;
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: millis,
    );
  } on FormatException {
    return null;
  }
}
