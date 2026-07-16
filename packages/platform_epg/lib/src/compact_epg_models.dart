import 'package:equatable/equatable.dart';

const String kCompactEpgSchemaVersion = '1.0.0';

enum CompactEpgSliceSource {
  localCache('local_cache'),
  delegatedNode('delegated_node'),
  embeddedFixture('embedded_fixture'),
  unavailable('unavailable');

  const CompactEpgSliceSource(this.stableId);

  final String stableId;
}

enum CompactEpgAvailability {
  available('available'),
  stale('stale'),
  unavailable('unavailable');

  const CompactEpgAvailability(this.stableId);

  final String stableId;
}

enum CompactEpgProgramKind {
  standard('standard'),
  movie('movie'),
  episode('episode'),
  sports('sports'),
  news('news');

  const CompactEpgProgramKind(this.stableId);

  final String stableId;
}

enum CompactEpgSourceRefRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value');

  const CompactEpgSourceRefRejectionCode(this.stableId);

  final String stableId;
}

class CompactEpgSourceRef extends Equatable {
  const CompactEpgSourceRef._(this.value);

  factory CompactEpgSourceRef.redacted(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return CompactEpgSourceRef._(value.trim());
  }

  final String value;

  static CompactEpgSourceRefRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return CompactEpgSourceRefRejectionCode.empty;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return CompactEpgSourceRefRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return CompactEpgSourceRefRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return CompactEpgSourceRefRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return CompactEpgSourceRefRejectionCode.credentialLikeValue;
    }

    return null;
  }

  @override
  String toString() => 'CompactEpgSourceRef(redacted)';

  @override
  List<Object?> get props => [value];
}

class CompactEpgProgram extends Equatable {
  const CompactEpgProgram({
    required this.programId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.eventId,
    this.subtitle,
    this.category,
    this.rating,
    this.kind = CompactEpgProgramKind.standard,
    this.schemaVersion = kCompactEpgSchemaVersion,
  });

  final String schemaVersion;
  final String programId;
  final String title;
  final String? eventId;
  final String? subtitle;
  final String? category;
  final String? rating;
  final CompactEpgProgramKind kind;
  final DateTime startsAt;
  final DateTime endsAt;

  bool isCurrentAt(DateTime now) =>
      !now.isBefore(startsAt) && now.isBefore(endsAt);

  bool startsAfter(DateTime now) => startsAt.isAfter(now);

  Duration get duration => endsAt.difference(startsAt);

  @override
  List<Object?> get props => [
    schemaVersion,
    programId,
    title,
    eventId,
    subtitle,
    category,
    rating,
    kind,
    startsAt,
    endsAt,
  ];
}

class CompactEpgEntry extends Equatable {
  const CompactEpgEntry({
    required this.channelId,
    required this.channelName,
    this.channelNumber,
    this.current,
    this.next,
    this.sourceRef,
    this.schemaVersion = kCompactEpgSchemaVersion,
  });

  factory CompactEpgEntry.fromPrograms({
    required String channelId,
    required String channelName,
    required DateTime now,
    required Iterable<CompactEpgProgram> programs,
    String? channelNumber,
    CompactEpgSourceRef? sourceRef,
  }) {
    final sorted = programs.toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    CompactEpgProgram? current;
    CompactEpgProgram? next;

    for (final program in sorted) {
      if (current == null && program.isCurrentAt(now)) {
        current = program;
        continue;
      }
      if (program.startsAfter(now)) {
        next = program;
        break;
      }
    }

    return CompactEpgEntry(
      channelId: channelId,
      channelName: channelName,
      channelNumber: channelNumber,
      current: current,
      next: next,
      sourceRef: sourceRef,
    );
  }

  final String schemaVersion;
  final String channelId;
  final String channelName;
  final String? channelNumber;
  final CompactEpgProgram? current;
  final CompactEpgProgram? next;
  final CompactEpgSourceRef? sourceRef;

  bool get hasPrograms => current != null || next != null;

  CompactEpgProgram? programAt(DateTime now) {
    final currentProgram = current;
    if (currentProgram != null && currentProgram.isCurrentAt(now)) {
      return currentProgram;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    channelId,
    channelName,
    channelNumber,
    current,
    next,
    sourceRef,
  ];
}

class CompactEpgSlice extends Equatable {
  CompactEpgSlice({
    required Iterable<CompactEpgEntry> entries,
    required this.generatedAt,
    required this.expiresAt,
    required this.source,
    this.schemaVersion = kCompactEpgSchemaVersion,
  }) : entries = List.unmodifiable(entries);

  final String schemaVersion;
  final List<CompactEpgEntry> entries;
  final DateTime generatedAt;
  final DateTime expiresAt;
  final CompactEpgSliceSource source;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  CompactEpgAvailability availabilityAt(DateTime now) {
    if (entries.isEmpty || source == CompactEpgSliceSource.unavailable) {
      return CompactEpgAvailability.unavailable;
    }
    if (isExpired(now)) {
      return CompactEpgAvailability.stale;
    }
    return CompactEpgAvailability.available;
  }

  CompactEpgEntry? entryForChannel(String channelId) {
    for (final entry in entries) {
      if (entry.channelId == channelId) {
        return entry;
      }
    }
    return null;
  }

  CompactEpgSlice filterForChannels(Iterable<String> channelIds) {
    final byChannelId = {for (final entry in entries) entry.channelId: entry};
    return CompactEpgSlice(
      entries: [
        for (final channelId in channelIds)
          if (byChannelId[channelId] != null) byChannelId[channelId]!,
      ],
      generatedAt: generatedAt,
      expiresAt: expiresAt,
      source: source,
      schemaVersion: schemaVersion,
    );
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    entries,
    generatedAt,
    expiresAt,
    source,
  ];
}

/// A bounded guide-window request: which channels, what time range, and the
/// reference "now" for current/next classification within that range.
///
/// Mirrors the query shape from CV-015 — repositories must return only
/// programmes intersecting [windowStart, windowEnd), never the full
/// timetable.
class GuideWindowQuery extends Equatable {
  GuideWindowQuery({
    required Iterable<String> channelIds,
    required DateTime windowStart,
    required DateTime windowEnd,
    required DateTime now,
  }) : channelIds = List.unmodifiable(channelIds),
       windowStart = windowStart.toUtc(),
       windowEnd = windowEnd.toUtc(),
       now = now.toUtc() {
    if (!this.windowEnd.isAfter(this.windowStart)) {
      throw ArgumentError.value(
        windowEnd,
        'windowEnd',
        'must be after windowStart',
      );
    }
  }

  final List<String> channelIds;
  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime now;

  @override
  List<Object?> get props => [channelIds, windowStart, windowEnd, now];
}

/// One channel's programmes intersecting a [GuideWindowQuery]'s time range,
/// in start-time order.
class CompactEpgWindowEntry extends Equatable {
  const CompactEpgWindowEntry({
    required this.channelId,
    required this.channelName,
    required this.programs,
    this.channelNumber,
    this.sourceRef,
  });

  final String channelId;
  final String channelName;
  final String? channelNumber;
  final List<CompactEpgProgram> programs;
  final CompactEpgSourceRef? sourceRef;

  @override
  List<Object?> get props => [
    channelId,
    channelName,
    channelNumber,
    programs,
    sourceRef,
  ];
}

/// The result of a [GuideWindowQuery]: bounded per-channel programme lists,
/// never the full XMLTV timetable.
class CompactEpgWindow extends Equatable {
  CompactEpgWindow({
    required Iterable<CompactEpgWindowEntry> entries,
    required this.windowStart,
    required this.windowEnd,
    required this.generatedAt,
    required this.expiresAt,
    required this.source,
    this.schemaVersion = kCompactEpgSchemaVersion,
  }) : entries = List.unmodifiable(entries);

  final String schemaVersion;
  final List<CompactEpgWindowEntry> entries;
  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime generatedAt;
  final DateTime expiresAt;
  final CompactEpgSliceSource source;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  CompactEpgAvailability availabilityAt(DateTime now) {
    if (entries.isEmpty || source == CompactEpgSliceSource.unavailable) {
      return CompactEpgAvailability.unavailable;
    }
    if (isExpired(now)) {
      return CompactEpgAvailability.stale;
    }
    return CompactEpgAvailability.available;
  }

  CompactEpgWindowEntry? entryForChannel(String channelId) {
    for (final entry in entries) {
      if (entry.channelId == channelId) {
        return entry;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    entries,
    windowStart,
    windowEnd,
    generatedAt,
    expiresAt,
    source,
  ];
}

abstract class CompactEpgRepository {
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  });

  /// Bounded window lookup per CV-015: only programmes with
  /// `endsAt > query.windowStart && startsAt < query.windowEnd` are
  /// returned, per channel, in start-time order. Implementations must not
  /// materialize the full timetable to satisfy this — see
  /// [XmltvCompactEpgRepository.loadWindow] for the reference filter.
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query);
}

class EmptyCompactEpgRepository implements CompactEpgRepository {
  const EmptyCompactEpgRepository({this.maxAge = const Duration(minutes: 1)});

  final Duration maxAge;

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) async {
    return CompactEpgSlice(
      entries: const [],
      generatedAt: now,
      expiresAt: now.add(maxAge),
      source: CompactEpgSliceSource.unavailable,
    );
  }

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) async {
    return CompactEpgWindow(
      entries: const [],
      windowStart: query.windowStart,
      windowEnd: query.windowEnd,
      generatedAt: query.now,
      expiresAt: query.now.add(maxAge),
      source: CompactEpgSliceSource.unavailable,
    );
  }
}

class InMemoryCompactEpgRepository implements CompactEpgRepository {
  InMemoryCompactEpgRepository({required CompactEpgSlice seed}) : _slice = seed;

  CompactEpgSlice _slice;

  CompactEpgSlice get slice => _slice;

  void replace(CompactEpgSlice slice) {
    _slice = slice;
  }

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) async {
    return _slice.filterForChannels(channelIds);
  }

  /// Best-effort: this cache only ever holds current/next programmes, not a
  /// full timetable, so the result is those programmes intersecting the
  /// window rather than the complete window contents.
  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) async {
    final filtered = _slice.filterForChannels(query.channelIds);
    final entries = <CompactEpgWindowEntry>[
      for (final entry in filtered.entries)
        CompactEpgWindowEntry(
          channelId: entry.channelId,
          channelName: entry.channelName,
          channelNumber: entry.channelNumber,
          sourceRef: entry.sourceRef,
          programs: [
            for (final program in [entry.current, entry.next])
              if (program != null &&
                  program.endsAt.isAfter(query.windowStart) &&
                  program.startsAt.isBefore(query.windowEnd))
                program,
          ],
        ),
    ];

    return CompactEpgWindow(
      entries: entries,
      windowStart: query.windowStart,
      windowEnd: query.windowEnd,
      generatedAt: filtered.generatedAt,
      expiresAt: filtered.expiresAt,
      source: filtered.source,
    );
  }
}
