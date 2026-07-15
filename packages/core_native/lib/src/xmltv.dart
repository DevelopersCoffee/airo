import 'package:flutter/foundation.dart' show kIsWeb;

import 'frb_generated.dart' as frb;

class NativeXmltvProgramme {
  const NativeXmltvProgramme({
    required this.channelId,
    required this.start,
    this.stop,
    this.title,
  });

  final String channelId;
  final String start;
  final String? stop;
  final String? title;
}

class NativeXmltvParseStats {
  const NativeXmltvParseStats({
    required this.programmeCount,
    required this.skippedProgrammeCount,
    required this.truncated,
  });

  final int programmeCount;
  final int skippedProgrammeCount;
  final bool truncated;
}

class NativeXmltvParseResult {
  const NativeXmltvParseResult({required this.programmes, required this.stats});

  final List<NativeXmltvProgramme> programmes;
  final NativeXmltvParseStats stats;
}

NativeXmltvParseResult parseXmltvProgrammes(
  String content, {
  int maxProgrammes = 1000,
}) {
  if (maxProgrammes < 0) {
    throw ArgumentError.value(maxProgrammes, 'maxProgrammes', 'must be >= 0');
  }

  if (kIsWeb) {
    return _dartParseXmltvProgrammes(content, maxProgrammes: maxProgrammes);
  }

  try {
    final result = frb.parseXmltvProgrammes(
      content: content,
      maxProgrammes: maxProgrammes,
    );
    return NativeXmltvParseResult(
      programmes: result.programmes
          .map(
            (programme) => NativeXmltvProgramme(
              channelId: programme.channelId,
              start: programme.start,
              stop: programme.stop,
              title: programme.title,
            ),
          )
          .toList(growable: false),
      stats: NativeXmltvParseStats(
        programmeCount: result.stats.programmeCount,
        skippedProgrammeCount: result.stats.skippedProgrammeCount,
        truncated: result.stats.truncated,
      ),
    );
  } on frb.NativeBridgeUnavailableException {
    return _dartParseXmltvProgrammes(content, maxProgrammes: maxProgrammes);
  }
}

NativeXmltvParseResult _dartParseXmltvProgrammes(
  String content, {
  required int maxProgrammes,
}) {
  final programmes = <NativeXmltvProgramme>[];
  var programmeCount = 0;
  var skippedProgrammeCount = 0;
  var truncated = false;

  final programmePattern = RegExp(
    r'<programme\b([^>]*)>(.*?)</programme>',
    caseSensitive: false,
    dotAll: true,
  );

  for (final match in programmePattern.allMatches(content)) {
    final attributes = match.group(1) ?? '';
    final body = match.group(2) ?? '';
    final channelId = _xmlAttribute(attributes, 'channel');
    final start = _xmlAttribute(attributes, 'start');

    if (channelId == null || start == null) {
      skippedProgrammeCount++;
      continue;
    }

    programmeCount++;
    if (programmes.length >= maxProgrammes) {
      truncated = true;
      continue;
    }

    programmes.add(
      NativeXmltvProgramme(
        channelId: channelId,
        start: start,
        stop: _xmlAttribute(attributes, 'stop'),
        title: _xmlText(body, 'title'),
      ),
    );
  }

  return NativeXmltvParseResult(
    programmes: List.unmodifiable(programmes),
    stats: NativeXmltvParseStats(
      programmeCount: programmeCount,
      skippedProgrammeCount: skippedProgrammeCount,
      truncated: truncated,
    ),
  );
}

String? _xmlAttribute(String attributes, String name) {
  final pattern = RegExp('$name="([^"]*)"', caseSensitive: false);
  final match = pattern.firstMatch(attributes);
  final value = match?.group(1)?.trim();
  if (value == null || value.isEmpty) return null;
  return _decodeXmlEntities(value);
}

String? _xmlText(String body, String tag) {
  final pattern = RegExp(
    '<$tag\\b[^>]*>(.*?)</$tag>',
    caseSensitive: false,
    dotAll: true,
  );
  final match = pattern.firstMatch(body);
  final value = match?.group(1)?.trim();
  if (value == null || value.isEmpty) return null;
  return _decodeXmlEntities(value);
}

String _decodeXmlEntities(String value) {
  return value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
