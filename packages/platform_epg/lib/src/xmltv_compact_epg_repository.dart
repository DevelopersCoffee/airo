import 'package:core_native/core_native.dart';
import 'package:equatable/equatable.dart';

import 'compact_epg_models.dart';

const Duration kXmltvCompactEpgDefaultMaxAge = Duration(minutes: 15);
const Duration kXmltvCompactEpgDefaultProgrammeDuration = Duration(minutes: 30);
const int kXmltvCompactEpgDefaultMaxProgrammes = 100000;

class XmltvCompactEpgIngestStats extends Equatable {
  const XmltvCompactEpgIngestStats({
    required this.nativeProgrammeCount,
    required this.nativeSkippedProgrammeCount,
    required this.nativeTruncated,
    required this.nativeBackend,
    required this.retainedProgrammeCount,
    required this.invalidTimestampCount,
  });

  final int nativeProgrammeCount;
  final int nativeSkippedProgrammeCount;
  final bool nativeTruncated;
  final String nativeBackend;
  final int retainedProgrammeCount;
  final int invalidTimestampCount;

  @override
  List<Object?> get props => [
    nativeProgrammeCount,
    nativeSkippedProgrammeCount,
    nativeTruncated,
    nativeBackend,
    retainedProgrammeCount,
    invalidTimestampCount,
  ];
}

class XmltvCompactEpgRepository implements CompactEpgRepository {
  XmltvCompactEpgRepository._({
    required Map<String, List<CompactEpgProgram>> programsByChannel,
    required this.ingestedAt,
    required this.expiresAt,
    required this.stats,
    required this.sourceRef,
    required Map<String, String> channelNamesById,
    required Map<String, String> channelNumbersById,
  }) : _programsByChannel = {
         for (final entry in programsByChannel.entries)
           entry.key: List.unmodifiable(entry.value),
       },
       _channelNamesById = Map.unmodifiable(channelNamesById),
       _channelNumbersById = Map.unmodifiable(channelNumbersById);

  factory XmltvCompactEpgRepository.fromXmltv({
    required String content,
    required DateTime ingestedAt,
    int maxProgrammes = kXmltvCompactEpgDefaultMaxProgrammes,
    Duration maxAge = kXmltvCompactEpgDefaultMaxAge,
    Duration defaultProgrammeDuration =
        kXmltvCompactEpgDefaultProgrammeDuration,
    CompactEpgSourceRef? sourceRef,
    Map<String, String> channelNamesById = const {},
    Map<String, String> channelNumbersById = const {},
  }) {
    final nativeResult = parseXmltvProgrammes(
      content,
      maxProgrammes: maxProgrammes,
    );
    return XmltvCompactEpgRepository._fromNativeResult(
      nativeResult: nativeResult,
      ingestedAt: ingestedAt,
      maxAge: maxAge,
      defaultProgrammeDuration: defaultProgrammeDuration,
      sourceRef: sourceRef,
      channelNamesById: channelNamesById,
      channelNumbersById: channelNumbersById,
    );
  }

  factory XmltvCompactEpgRepository.fromXmltvFile({
    required String path,
    required DateTime ingestedAt,
    int maxProgrammes = kXmltvCompactEpgDefaultMaxProgrammes,
    Duration maxAge = kXmltvCompactEpgDefaultMaxAge,
    Duration defaultProgrammeDuration =
        kXmltvCompactEpgDefaultProgrammeDuration,
    CompactEpgSourceRef? sourceRef,
    Map<String, String> channelNamesById = const {},
    Map<String, String> channelNumbersById = const {},
  }) {
    final nativeResult = parseXmltvProgrammesFile(
      path,
      maxProgrammes: maxProgrammes,
    );
    return XmltvCompactEpgRepository._fromNativeResult(
      nativeResult: nativeResult,
      ingestedAt: ingestedAt,
      maxAge: maxAge,
      defaultProgrammeDuration: defaultProgrammeDuration,
      sourceRef: sourceRef,
      channelNamesById: channelNamesById,
      channelNumbersById: channelNumbersById,
    );
  }

  static Future<XmltvCompactEpgRepository> fromXmltvFileNative({
    required String path,
    required DateTime ingestedAt,
    int maxProgrammes = kXmltvCompactEpgDefaultMaxProgrammes,
    Duration maxAge = kXmltvCompactEpgDefaultMaxAge,
    Duration defaultProgrammeDuration =
        kXmltvCompactEpgDefaultProgrammeDuration,
    CompactEpgSourceRef? sourceRef,
    Map<String, String> channelNamesById = const {},
    Map<String, String> channelNumbersById = const {},
  }) async {
    final nativeResult = await parseXmltvProgrammesFileNative(
      path,
      maxProgrammes: maxProgrammes,
    );
    return XmltvCompactEpgRepository._fromNativeResult(
      nativeResult: nativeResult,
      ingestedAt: ingestedAt,
      maxAge: maxAge,
      defaultProgrammeDuration: defaultProgrammeDuration,
      sourceRef: sourceRef,
      channelNamesById: channelNamesById,
      channelNumbersById: channelNumbersById,
    );
  }

  factory XmltvCompactEpgRepository._fromNativeResult({
    required NativeXmltvParseResult nativeResult,
    required DateTime ingestedAt,
    required Duration maxAge,
    required Duration defaultProgrammeDuration,
    required CompactEpgSourceRef? sourceRef,
    required Map<String, String> channelNamesById,
    required Map<String, String> channelNumbersById,
  }) {
    final programsByChannel = <String, List<CompactEpgProgram>>{};
    var retainedProgrammeCount = 0;
    var invalidTimestampCount = 0;

    for (var index = 0; index < nativeResult.programmes.length; index++) {
      final nativeProgramme = nativeResult.programmes[index];
      final startsAt = parseXmltvTimestamp(nativeProgramme.start);
      if (startsAt == null) {
        invalidTimestampCount++;
        continue;
      }

      final parsedEndsAt = nativeProgramme.stop == null
          ? null
          : parseXmltvTimestamp(nativeProgramme.stop!);
      if (nativeProgramme.stop != null && parsedEndsAt == null) {
        invalidTimestampCount++;
        continue;
      }

      final endsAt = parsedEndsAt ?? startsAt.add(defaultProgrammeDuration);
      if (!endsAt.isAfter(startsAt)) {
        invalidTimestampCount++;
        continue;
      }

      final channelPrograms = programsByChannel.putIfAbsent(
        nativeProgramme.channelId,
        () => <CompactEpgProgram>[],
      );
      channelPrograms.add(
        CompactEpgProgram(
          programId: _programId(nativeProgramme, startsAt, endsAt, index),
          title: _programTitle(nativeProgramme),
          startsAt: startsAt,
          endsAt: endsAt,
        ),
      );
      retainedProgrammeCount++;
    }

    for (final programs in programsByChannel.values) {
      programs.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    }

    return XmltvCompactEpgRepository._(
      programsByChannel: programsByChannel,
      ingestedAt: ingestedAt.toUtc(),
      expiresAt: ingestedAt.toUtc().add(maxAge),
      stats: XmltvCompactEpgIngestStats(
        nativeProgrammeCount: nativeResult.stats.programmeCount,
        nativeSkippedProgrammeCount: nativeResult.stats.skippedProgrammeCount,
        nativeTruncated: nativeResult.stats.truncated,
        nativeBackend: nativeResult.backend.stableId,
        retainedProgrammeCount: retainedProgrammeCount,
        invalidTimestampCount: invalidTimestampCount,
      ),
      sourceRef: sourceRef,
      channelNamesById: channelNamesById,
      channelNumbersById: channelNumbersById,
    );
  }

  final DateTime ingestedAt;
  final DateTime expiresAt;
  final XmltvCompactEpgIngestStats stats;
  final CompactEpgSourceRef? sourceRef;
  final Map<String, List<CompactEpgProgram>> _programsByChannel;
  final Map<String, String> _channelNamesById;
  final Map<String, String> _channelNumbersById;

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) async {
    final entries = <CompactEpgEntry>[];
    for (final channelId in channelIds) {
      final programs = _programsByChannel[channelId] ?? const [];
      final entry = CompactEpgEntry.fromPrograms(
        channelId: channelId,
        channelName: _channelNamesById[channelId] ?? channelId,
        channelNumber: _channelNumbersById[channelId],
        now: now.toUtc(),
        programs: programs,
        sourceRef: sourceRef,
      );
      if (entry.hasPrograms) {
        entries.add(entry);
      }
    }

    return CompactEpgSlice(
      entries: entries,
      generatedAt: ingestedAt,
      expiresAt: expiresAt,
      source: entries.isEmpty
          ? CompactEpgSliceSource.unavailable
          : CompactEpgSliceSource.localCache,
    );
  }
}

DateTime? parseXmltvTimestamp(String value) {
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
  } on ArgumentError {
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

String _programTitle(NativeXmltvProgramme programme) {
  final title = programme.title?.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }
  return 'Untitled programme';
}

String _programId(
  NativeXmltvProgramme programme,
  DateTime startsAt,
  DateTime endsAt,
  int index,
) {
  return [
    programme.channelId,
    startsAt.toUtc().toIso8601String(),
    endsAt.toUtc().toIso8601String(),
    index.toString(),
  ].join('|');
}
