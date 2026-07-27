import 'compact_epg_models.dart';

class EpgSourceDescriptor {
  EpgSourceDescriptor({
    required this.sourceId,
    required this.priority,
    required this.revision,
  }) {
    final rejection = CompactEpgSourceRef.validate(sourceId);
    if (rejection != null) {
      throw ArgumentError.value(sourceId, 'sourceId', rejection.stableId);
    }
    if (priority < 0) {
      throw ArgumentError.value(priority, 'priority', 'must not be negative');
    }
    if (revision.trim().isEmpty) {
      throw ArgumentError.value(revision, 'revision', 'must not be empty');
    }
  }

  final String sourceId;
  final int priority;
  final String revision;
}

class EpgSourceWindow {
  EpgSourceWindow({
    required this.source,
    required this.windowStart,
    required this.windowEnd,
    required Iterable<CompactEpgWindowEntry> entries,
    Iterable<String>? refreshedChannelIds,
    required this.generatedAt,
    required this.expiresAt,
  }) : entries = List.unmodifiable(entries),
       refreshedChannelIds = List.unmodifiable(
         refreshedChannelIds ?? entries.map((entry) => entry.channelId),
       ) {
    if (!windowEnd.isAfter(windowStart)) {
      throw ArgumentError.value(windowEnd, 'windowEnd', 'must be after start');
    }
  }

  final EpgSourceDescriptor source;
  final DateTime windowStart;
  final DateTime windowEnd;
  final List<CompactEpgWindowEntry> entries;
  final List<String> refreshedChannelIds;
  final DateTime generatedAt;
  final DateTime expiresAt;
}

class MultiSourceEpgMergePolicy {
  const MultiSourceEpgMergePolicy({
    this.inferAdjacentGaps = false,
    this.maximumInferredGap = const Duration(minutes: 5),
  });

  final bool inferAdjacentGaps;
  final Duration maximumInferredGap;
}

class MultiSourceEpgMerger {
  const MultiSourceEpgMerger({this.policy = const MultiSourceEpgMergePolicy()});

  final MultiSourceEpgMergePolicy policy;

  CompactEpgWindow merge({
    required GuideWindowQuery query,
    required Iterable<EpgSourceWindow> sources,
  }) {
    final orderedSources =
        sources
            .where(
              (source) =>
                  source.windowEnd.isAfter(query.windowStart) &&
                  source.windowStart.isBefore(query.windowEnd),
            )
            .toList()
          ..sort((left, right) {
            final priority = left.source.priority.compareTo(
              right.source.priority,
            );
            if (priority != 0) return priority;
            return left.source.sourceId.compareTo(right.source.sourceId);
          });
    final entries = <CompactEpgWindowEntry>[];
    for (final channelId in query.channelIds) {
      final candidates = <_RankedProgram>[];
      String channelName = channelId;
      String? channelNumber;
      var hasSourceEntry = false;
      for (final source in orderedSources) {
        final entry = source.entries
            .where((candidate) => candidate.channelId == channelId)
            .firstOrNull;
        if (entry == null) continue;
        hasSourceEntry = true;
        channelName = entry.channelName;
        channelNumber ??= entry.channelNumber;
        for (final program in entry.programs) {
          final normalized = _utcProgram(program);
          if (normalized.endsAt.isAfter(query.windowStart) &&
              normalized.startsAt.isBefore(query.windowEnd)) {
            candidates.add(
              _RankedProgram(
                program: normalized,
                priority: source.source.priority,
                sourceId: source.source.sourceId,
              ),
            );
          }
        }
      }
      candidates.sort(_compareCandidates);
      final selected = <_RankedProgram>[];
      final programIds = <String>{};
      final fallbackIdentities = <String>{};
      for (final candidate in candidates) {
        final programId = candidate.program.programId.trim();
        final fallbackIdentity = _fallbackIdentity(
          channelId,
          candidate.program,
        );
        if ((programId.isNotEmpty && programIds.contains(programId)) ||
            fallbackIdentities.contains(fallbackIdentity)) {
          continue;
        }
        if (selected.any(
          (existing) => _overlaps(existing.program, candidate.program),
        )) {
          continue;
        }
        if (programId.isNotEmpty) programIds.add(programId);
        fallbackIdentities.add(fallbackIdentity);
        selected.add(candidate);
      }
      selected.sort(
        (left, right) =>
            left.program.startsAt.compareTo(right.program.startsAt),
      );
      final programs = selected
          .map((candidate) => candidate.program)
          .toList(growable: false);
      final gaps = _gaps(query, programs);
      if (hasSourceEntry && (programs.isNotEmpty || gaps.isNotEmpty)) {
        entries.add(
          CompactEpgWindowEntry(
            channelId: channelId,
            channelName: channelName,
            channelNumber: channelNumber,
            programs: programs,
            gaps: gaps,
          ),
        );
      }
    }
    final generatedAt = orderedSources.isEmpty
        ? query.now.toUtc()
        : orderedSources
              .map((source) => source.generatedAt.toUtc())
              .reduce(_latest);
    final expiresAt = orderedSources.isEmpty
        ? query.now.toUtc()
        : orderedSources
              .map((source) => source.expiresAt.toUtc())
              .reduce(_earliest);
    return CompactEpgWindow(
      entries: entries,
      windowStart: query.windowStart.toUtc(),
      windowEnd: query.windowEnd.toUtc(),
      generatedAt: generatedAt,
      expiresAt: expiresAt,
      source: entries.isEmpty
          ? CompactEpgSliceSource.unavailable
          : CompactEpgSliceSource.localCache,
    );
  }

  List<CompactEpgGap> _gaps(
    GuideWindowQuery query,
    List<CompactEpgProgram> programs,
  ) {
    final gaps = <CompactEpgGap>[];
    var cursor = query.windowStart.toUtc();
    CompactEpgProgram? previous;
    for (final program in programs) {
      final start = program.startsAt.isBefore(query.windowStart)
          ? query.windowStart.toUtc()
          : program.startsAt;
      if (start.isAfter(cursor)) {
        gaps.add(_gap(cursor, start, previous));
      }
      if (program.endsAt.isAfter(cursor)) cursor = program.endsAt;
      previous = program;
    }
    final windowEnd = query.windowEnd.toUtc();
    if (windowEnd.isAfter(cursor)) gaps.add(_gap(cursor, windowEnd, previous));
    return List.unmodifiable(gaps);
  }

  CompactEpgGap _gap(
    DateTime startsAt,
    DateTime endsAt,
    CompactEpgProgram? previous,
  ) {
    final inferred =
        policy.inferAdjacentGaps &&
        previous != null &&
        endsAt.difference(startsAt) <= policy.maximumInferredGap;
    return CompactEpgGap(
      startsAt: startsAt,
      endsAt: endsAt,
      kind: inferred
          ? CompactEpgGapKind.inferredAdjacent
          : CompactEpgGapKind.explicit,
      adjacentProgramId: inferred ? previous.programId : null,
    );
  }
}

enum EpgRefreshStatus { applied, unchanged }

class EpgRefreshResult {
  const EpgRefreshResult({
    required this.status,
    required this.replacedProgrammeCount,
    required this.retainedProgrammeCount,
  });

  final EpgRefreshStatus status;
  final int replacedProgrammeCount;
  final int retainedProgrammeCount;
}

/// Mutable bounded-window cache. Callers parse/fetch changed source windows on
/// worker/native boundaries, then atomically apply only that compact refresh.
class IncrementalMultiSourceEpgRepository implements CompactEpgRepository {
  IncrementalMultiSourceEpgRepository({
    this.merger = const MultiSourceEpgMerger(),
  });

  final MultiSourceEpgMerger merger;
  final Map<String, EpgSourceWindow> _sources = {};

  List<String> get sourceIds =>
      List.unmodifiable(_sources.keys.toList()..sort());

  EpgRefreshResult applyRefresh(EpgSourceWindow refresh) {
    final existing = _sources[refresh.source.sourceId];
    if (existing?.source.revision == refresh.source.revision) {
      return const EpgRefreshResult(
        status: EpgRefreshStatus.unchanged,
        replacedProgrammeCount: 0,
        retainedProgrammeCount: 0,
      );
    }
    var replaced = 0;
    var retained = 0;
    final entries = <CompactEpgWindowEntry>[];
    final refreshedChannelIds = refresh.refreshedChannelIds.toSet();
    final channelIds = {
      ...?existing?.entries.map((entry) => entry.channelId),
      ...refresh.entries.map((entry) => entry.channelId),
    };
    for (final channelId in channelIds) {
      final oldEntry = existing?.entries
          .where((entry) => entry.channelId == channelId)
          .firstOrNull;
      final newEntry = refresh.entries
          .where((entry) => entry.channelId == channelId)
          .firstOrNull;
      final oldPrograms = oldEntry?.programs ?? const <CompactEpgProgram>[];
      final retainedPrograms = [
        for (final program in oldPrograms)
          if (!refreshedChannelIds.contains(channelId) ||
              !_intersects(program, refresh.windowStart, refresh.windowEnd))
            program,
      ];
      replaced += (oldEntry?.programs.length ?? 0) - retainedPrograms.length;
      retained += retainedPrograms.length;
      final programs = [...retainedPrograms, ...?newEntry?.programs]
        ..sort((left, right) => left.startsAt.compareTo(right.startsAt));
      if (programs.isNotEmpty) {
        entries.add(
          CompactEpgWindowEntry(
            channelId: channelId,
            channelName:
                newEntry?.channelName ?? oldEntry?.channelName ?? channelId,
            channelNumber: newEntry?.channelNumber ?? oldEntry?.channelNumber,
            programs: List.unmodifiable(programs),
          ),
        );
      }
    }
    _sources[refresh.source.sourceId] = EpgSourceWindow(
      source: refresh.source,
      windowStart: _earliest(
        existing?.windowStart.toUtc() ?? refresh.windowStart.toUtc(),
        refresh.windowStart.toUtc(),
      ),
      windowEnd: _latest(
        existing?.windowEnd.toUtc() ?? refresh.windowEnd.toUtc(),
        refresh.windowEnd.toUtc(),
      ),
      entries: entries,
      refreshedChannelIds: {
        ...?existing?.refreshedChannelIds,
        ...refresh.refreshedChannelIds,
      },
      generatedAt: refresh.generatedAt,
      expiresAt: refresh.expiresAt,
    );
    return EpgRefreshResult(
      status: EpgRefreshStatus.applied,
      replacedProgrammeCount: replaced,
      retainedProgrammeCount: retained,
    );
  }

  bool removeSource(String sourceId) => _sources.remove(sourceId) != null;

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) async {
    return merger.merge(query: query, sources: _sources.values);
  }

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) async {
    final window = await loadWindow(
      GuideWindowQuery(
        channelIds: channelIds,
        windowStart: now.toUtc(),
        windowEnd: now.toUtc().add(const Duration(days: 1)),
        now: now.toUtc(),
      ),
    );
    final entries = [
      for (final entry in window.entries)
        CompactEpgEntry.fromPrograms(
          channelId: entry.channelId,
          channelName: entry.channelName,
          channelNumber: entry.channelNumber,
          now: now.toUtc(),
          programs: entry.programs,
        ),
    ]..removeWhere((entry) => !entry.hasPrograms);
    return CompactEpgSlice(
      entries: entries,
      generatedAt: window.generatedAt,
      expiresAt: window.expiresAt,
      source: window.source,
    );
  }
}

class _RankedProgram {
  const _RankedProgram({
    required this.program,
    required this.priority,
    required this.sourceId,
  });

  final CompactEpgProgram program;
  final int priority;
  final String sourceId;
}

int _compareCandidates(_RankedProgram left, _RankedProgram right) {
  final priority = left.priority.compareTo(right.priority);
  if (priority != 0) return priority;
  final source = left.sourceId.compareTo(right.sourceId);
  if (source != 0) return source;
  final start = left.program.startsAt.compareTo(right.program.startsAt);
  if (start != 0) return start;
  return left.program.programId.compareTo(right.program.programId);
}

CompactEpgProgram _utcProgram(CompactEpgProgram program) {
  return CompactEpgProgram(
    programId: program.programId,
    title: program.title,
    startsAt: program.startsAt.toUtc(),
    endsAt: program.endsAt.toUtc(),
    eventId: program.eventId,
    subtitle: program.subtitle,
    category: program.category,
    rating: program.rating,
    description: program.description,
    categories: program.categories,
    episodeNumber: program.episodeNumber,
    iconUrl: program.iconUrl,
    isNew: program.isNew,
    isPremiere: program.isPremiere,
    previouslyShown: program.previouslyShown,
    kind: program.kind,
    schemaVersion: program.schemaVersion,
  );
}

String _fallbackIdentity(String channelId, CompactEpgProgram program) {
  final title = program.title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
  return 'fallback:$channelId:$title:'
      '${program.startsAt.toUtc().microsecondsSinceEpoch}:'
      '${program.endsAt.toUtc().microsecondsSinceEpoch}';
}

bool _overlaps(CompactEpgProgram left, CompactEpgProgram right) {
  return left.endsAt.isAfter(right.startsAt) &&
      left.startsAt.isBefore(right.endsAt);
}

bool _intersects(
  CompactEpgProgram program,
  DateTime windowStart,
  DateTime windowEnd,
) {
  return program.endsAt.isAfter(windowStart) &&
      program.startsAt.isBefore(windowEnd);
}

DateTime _latest(DateTime left, DateTime right) =>
    left.isAfter(right) ? left : right;

DateTime _earliest(DateTime left, DateTime right) =>
    left.isBefore(right) ? left : right;

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
