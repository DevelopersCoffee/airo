import 'package:flutter/foundation.dart' show kIsWeb;

import 'api/xmltv.dart' as native_xmltv;
import 'native_bridge.dart';
import 'xmltv_file_reader_stub.dart'
    if (dart.library.io) 'xmltv_file_reader_io.dart';

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

enum NativeXmltvParseBackend {
  nativeBridge('native_bridge'),
  dartFallback('dart_fallback');

  const NativeXmltvParseBackend(this.stableId);

  final String stableId;
}

class NativeXmltvParseResult {
  const NativeXmltvParseResult({
    required this.programmes,
    required this.stats,
    this.backend = NativeXmltvParseBackend.dartFallback,
  });

  final List<NativeXmltvProgramme> programmes;
  final NativeXmltvParseStats stats;
  final NativeXmltvParseBackend backend;
}

class NativeXmltvCurrentNextStats {
  const NativeXmltvCurrentNextStats({
    required this.programmeCount,
    required this.skippedProgrammeCount,
    required this.invalidTimestampCount,
    required this.matchedProgrammeCount,
    required this.requestedChannelCount,
  });

  final int programmeCount;
  final int skippedProgrammeCount;
  final int invalidTimestampCount;
  final int matchedProgrammeCount;
  final int requestedChannelCount;
}

class NativeXmltvCurrentNextEntry {
  const NativeXmltvCurrentNextEntry({
    required this.channelId,
    this.current,
    this.next,
  });

  final String channelId;
  final NativeXmltvProgramme? current;
  final NativeXmltvProgramme? next;
}

class NativeXmltvCurrentNextResult {
  const NativeXmltvCurrentNextResult({
    required this.entries,
    required this.stats,
    this.backend = NativeXmltvParseBackend.dartFallback,
  });

  final List<NativeXmltvCurrentNextEntry> entries;
  final NativeXmltvCurrentNextStats stats;
  final NativeXmltvParseBackend backend;
}

NativeXmltvParseResult parseXmltvProgrammes(
  String content, {
  int maxProgrammes = 1000,
}) {
  if (maxProgrammes < 0) {
    throw ArgumentError.value(maxProgrammes, 'maxProgrammes', 'must be >= 0');
  }

  return _dartParseXmltvProgrammes(content, maxProgrammes: maxProgrammes);
}

Future<NativeXmltvParseResult> parseXmltvProgrammesNative(
  String content, {
  int maxProgrammes = 1000,
}) async {
  if (maxProgrammes < 0) {
    throw ArgumentError.value(maxProgrammes, 'maxProgrammes', 'must be >= 0');
  }

  if (kIsWeb) {
    return _dartParseXmltvProgrammes(content, maxProgrammes: maxProgrammes);
  }

  if (!await initializeCoreNativeBridge()) {
    return _dartParseXmltvProgrammes(content, maxProgrammes: maxProgrammes);
  }

  try {
    final result = await native_xmltv.parseXmltvProgrammes(
      content: content,
      maxProgrammes: maxProgrammes,
    );
    return _fromNativeXmltvParseResult(result);
  } on Object {
    return _dartParseXmltvProgrammes(content, maxProgrammes: maxProgrammes);
  }
}

NativeXmltvParseResult parseXmltvProgrammesFile(
  String path, {
  int maxProgrammes = 1000,
}) {
  if (maxProgrammes < 0) {
    throw ArgumentError.value(maxProgrammes, 'maxProgrammes', 'must be >= 0');
  }

  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    throw ArgumentError.value(path, 'path', 'must not be empty');
  }

  if (kIsWeb) {
    throw UnsupportedError(
      'XMLTV file parsing is not available on web. '
      'Use parseXmltvProgrammes with XMLTV content instead.',
    );
  }

  return _dartParseXmltvProgrammes(
    readXmltvFileSync(normalizedPath),
    maxProgrammes: maxProgrammes,
  );
}

Future<NativeXmltvParseResult> parseXmltvProgrammesFileNative(
  String path, {
  int maxProgrammes = 1000,
}) async {
  if (maxProgrammes < 0) {
    throw ArgumentError.value(maxProgrammes, 'maxProgrammes', 'must be >= 0');
  }

  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    throw ArgumentError.value(path, 'path', 'must not be empty');
  }

  if (kIsWeb) {
    throw UnsupportedError(
      'XMLTV file parsing is not available on web. '
      'Use parseXmltvProgrammes with XMLTV content instead.',
    );
  }

  if (!await initializeCoreNativeBridge()) {
    return _dartParseXmltvProgrammes(
      readXmltvFileSync(normalizedPath),
      maxProgrammes: maxProgrammes,
    );
  }

  try {
    final result = await native_xmltv.parseXmltvProgrammesFile(
      path: normalizedPath,
      maxProgrammes: maxProgrammes,
    );
    return _fromNativeXmltvParseResult(result);
  } on Object {
    return _dartParseXmltvProgrammes(
      readXmltvFileSync(normalizedPath),
      maxProgrammes: maxProgrammes,
    );
  }
}

Future<NativeXmltvCurrentNextResult> parseXmltvCurrentNextFileNative(
  String path, {
  required Iterable<String> channelIds,
  required DateTime now,
  Duration defaultProgrammeDuration = const Duration(minutes: 30),
}) async {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    throw ArgumentError.value(path, 'path', 'must not be empty');
  }
  if (defaultProgrammeDuration <= Duration.zero) {
    throw ArgumentError.value(
      defaultProgrammeDuration,
      'defaultProgrammeDuration',
      'must be > 0',
    );
  }

  final requestedChannelIds = _normalizedChannelIds(channelIds);
  if (kIsWeb) {
    throw UnsupportedError(
      'XMLTV file parsing is not available on web. '
      'Use parseXmltvProgrammes with XMLTV content instead.',
    );
  }
  if (requestedChannelIds.isEmpty) {
    return const NativeXmltvCurrentNextResult(
      entries: [],
      stats: NativeXmltvCurrentNextStats(
        programmeCount: 0,
        skippedProgrammeCount: 0,
        invalidTimestampCount: 0,
        matchedProgrammeCount: 0,
        requestedChannelCount: 0,
      ),
    );
  }

  if (!await initializeCoreNativeBridge()) {
    return _dartParseXmltvCurrentNext(
      readXmltvFileSync(normalizedPath),
      channelIds: requestedChannelIds,
      now: now,
      defaultProgrammeDuration: defaultProgrammeDuration,
    );
  }

  try {
    final result = await native_xmltv.parseXmltvCurrentNextFile(
      path: normalizedPath,
      channelIds: requestedChannelIds,
      nowEpochSeconds: now.toUtc().millisecondsSinceEpoch ~/ 1000,
      defaultDurationSeconds: defaultProgrammeDuration.inSeconds,
    );
    return _fromNativeXmltvCurrentNextResult(result);
  } on Object {
    return _dartParseXmltvCurrentNext(
      readXmltvFileSync(normalizedPath),
      channelIds: requestedChannelIds,
      now: now,
      defaultProgrammeDuration: defaultProgrammeDuration,
    );
  }
}

NativeXmltvParseResult _fromNativeXmltvParseResult(
  native_xmltv.XmltvParseResult result,
) {
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
    backend: NativeXmltvParseBackend.nativeBridge,
    stats: NativeXmltvParseStats(
      programmeCount: result.stats.programmeCount,
      skippedProgrammeCount: result.stats.skippedProgrammeCount,
      truncated: result.stats.truncated,
    ),
  );
}

NativeXmltvCurrentNextResult _fromNativeXmltvCurrentNextResult(
  native_xmltv.XmltvCurrentNextResult result,
) {
  return NativeXmltvCurrentNextResult(
    entries: result.entries
        .map(
          (entry) => NativeXmltvCurrentNextEntry(
            channelId: entry.channelId,
            current: _fromNativeXmltvProgramme(entry.current),
            next: _fromNativeXmltvProgramme(entry.next),
          ),
        )
        .toList(growable: false),
    backend: NativeXmltvParseBackend.nativeBridge,
    stats: NativeXmltvCurrentNextStats(
      programmeCount: result.stats.programmeCount,
      skippedProgrammeCount: result.stats.skippedProgrammeCount,
      invalidTimestampCount: result.stats.invalidTimestampCount,
      matchedProgrammeCount: result.stats.matchedProgrammeCount,
      requestedChannelCount: result.stats.requestedChannelCount,
    ),
  );
}

NativeXmltvProgramme? _fromNativeXmltvProgramme(
  native_xmltv.XmltvProgramme? programme,
) {
  if (programme == null) return null;
  return NativeXmltvProgramme(
    channelId: programme.channelId,
    start: programme.start,
    stop: programme.stop,
    title: programme.title,
  );
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

NativeXmltvCurrentNextResult _dartParseXmltvCurrentNext(
  String content, {
  required List<String> channelIds,
  required DateTime now,
  required Duration defaultProgrammeDuration,
}) {
  final indexByChannelId = {
    for (var index = 0; index < channelIds.length; index++)
      channelIds[index]: index,
  };
  final candidates = List<_CurrentNextCandidate>.generate(
    channelIds.length,
    (_) => const _CurrentNextCandidate(),
    growable: false,
  );
  final programmes = _dartParseXmltvProgrammes(
    content,
    maxProgrammes: 0x7fffffff,
  );
  var invalidTimestampCount = 0;
  var matchedProgrammeCount = 0;
  final nowUtc = now.toUtc();

  for (final programme in programmes.programmes) {
    final candidateIndex = indexByChannelId[programme.channelId];
    if (candidateIndex == null) {
      continue;
    }

    final startsAt = _parseXmltvTimestamp(programme.start);
    if (startsAt == null) {
      invalidTimestampCount++;
      continue;
    }
    final parsedEndsAt = programme.stop == null
        ? null
        : _parseXmltvTimestamp(programme.stop!);
    if (programme.stop != null && parsedEndsAt == null) {
      invalidTimestampCount++;
      continue;
    }
    final endsAt = parsedEndsAt ?? startsAt.add(defaultProgrammeDuration);
    if (!endsAt.isAfter(startsAt)) {
      invalidTimestampCount++;
      continue;
    }

    matchedProgrammeCount++;
    candidates[candidateIndex] = candidates[candidateIndex].add(
      programme: programme,
      startsAt: startsAt,
      endsAt: endsAt,
      now: nowUtc,
    );
  }

  return NativeXmltvCurrentNextResult(
    entries: [
      for (var index = 0; index < channelIds.length; index++)
        if (candidates[index].current != null || candidates[index].next != null)
          NativeXmltvCurrentNextEntry(
            channelId: channelIds[index],
            current: candidates[index].current?.programme,
            next: candidates[index].next?.programme,
          ),
    ],
    stats: NativeXmltvCurrentNextStats(
      programmeCount: programmes.stats.programmeCount,
      skippedProgrammeCount: programmes.stats.skippedProgrammeCount,
      invalidTimestampCount: invalidTimestampCount,
      matchedProgrammeCount: matchedProgrammeCount,
      requestedChannelCount: channelIds.length,
    ),
  );
}

List<String> _normalizedChannelIds(Iterable<String> channelIds) {
  final seen = <String>{};
  return [
    for (final channelId in channelIds)
      if (channelId.trim().isNotEmpty && seen.add(channelId.trim()))
        channelId.trim(),
  ];
}

DateTime? _parseXmltvTimestamp(String value) {
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(?:\s*([+-])(\d{2})(\d{2}))?$',
  ).firstMatch(value.trim());
  if (match == null) return null;

  try {
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    if (!_isValidUtcComponent(
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: second,
    )) {
      return null;
    }
    final local = DateTime.utc(year, month, day, hour, minute, second);
    final sign = match.group(7);
    if (sign == null) return local;

    final offset = Duration(
      hours: int.parse(match.group(8)!),
      minutes: int.parse(match.group(9)!),
    );
    return sign == '+' ? local.subtract(offset) : local.add(offset);
  } on FormatException {
    return null;
  }
}

bool _isValidUtcComponent({
  required int year,
  required int month,
  required int day,
  required int hour,
  required int minute,
  required int second,
}) {
  if (month < 1 || month > 12) return false;
  if (day < 1 || day > DateTime.utc(year, month + 1, 0).day) return false;
  if (hour < 0 || hour > 23) return false;
  if (minute < 0 || minute > 59) return false;
  if (second < 0 || second > 59) return false;
  return true;
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

class _CurrentNextCandidate {
  const _CurrentNextCandidate({this.current, this.next});

  final _TimedProgramme? current;
  final _TimedProgramme? next;

  _CurrentNextCandidate add({
    required NativeXmltvProgramme programme,
    required DateTime startsAt,
    required DateTime endsAt,
    required DateTime now,
  }) {
    if (!startsAt.isAfter(now) && now.isBefore(endsAt)) {
      final shouldReplace =
          current == null || startsAt.isBefore(current!.startsAt);
      return shouldReplace
          ? _CurrentNextCandidate(
              current: _TimedProgramme(programme, startsAt),
              next: next,
            )
          : this;
    }
    if (startsAt.isAfter(now)) {
      final shouldReplace = next == null || startsAt.isBefore(next!.startsAt);
      return shouldReplace
          ? _CurrentNextCandidate(
              current: current,
              next: _TimedProgramme(programme, startsAt),
            )
          : this;
    }
    return this;
  }
}

class _TimedProgramme {
  const _TimedProgramme(this.programme, this.startsAt);

  final NativeXmltvProgramme programme;
  final DateTime startsAt;
}
