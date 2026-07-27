import 'package:platform_epg/platform_epg.dart';

/// A [CompactEpgRepository] whose underlying data source can be swapped at
/// runtime. Used as the `fallback` of the app's [SnapshotBackedCompactEpgRepository]
/// in `main_tv.dart`: starts out delegating to [EmptyCompactEpgRepository]
/// (matching today's behavior, no regression), then [updateSource] is called
/// by [XmltvSourceRefreshService] once the user configures and successfully
/// refreshes an XMLTV source — no Riverpod provider re-override needed,
/// callers just re-query the same [compactEpgWindowProvider]/`.family`
/// instance after invalidation.
class MutableXmltvCompactEpgRepository implements CompactEpgRepository {
  MutableXmltvCompactEpgRepository({CompactEpgRepository? initial}) {
    if (initial != null) updateSource(initial);
  }

  final Map<String, _XmltvRepositorySource> _sources = {};
  var _revision = 0;

  /// Swaps the delegate. Pass `null` to revert to unavailable (e.g. when a
  /// source is removed).
  void updateSource(CompactEpgRepository? repository) {
    _sources.clear();
    if (repository != null) {
      updateNamedSource(
        sourceId: 'xmltv-user',
        priority: 0,
        repository: repository,
      );
    }
  }

  void updateNamedSource({
    required String sourceId,
    required int priority,
    required CompactEpgRepository repository,
  }) {
    _sources[sourceId] = _XmltvRepositorySource(
      sourceId: sourceId,
      priority: priority,
      revision: '${++_revision}',
      repository: repository,
    );
  }

  bool removeNamedSource(String sourceId) => _sources.remove(sourceId) != null;

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

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) async {
    if (_sources.isEmpty) {
      return const EmptyCompactEpgRepository().loadWindow(query);
    }
    final sources = _sources.values.toList(growable: false);
    final windows = await Future.wait([
      for (final source in sources) source.repository.loadWindow(query),
    ]);
    return const MultiSourceEpgMerger().merge(
      query: query,
      sources: [
        for (var index = 0; index < sources.length; index++)
          EpgSourceWindow(
            source: EpgSourceDescriptor(
              sourceId: sources[index].sourceId,
              priority: sources[index].priority,
              revision: sources[index].revision,
            ),
            windowStart: windows[index].windowStart,
            windowEnd: windows[index].windowEnd,
            entries: windows[index].entries,
            generatedAt: windows[index].generatedAt,
            expiresAt: windows[index].expiresAt,
          ),
      ],
    );
  }
}

class _XmltvRepositorySource {
  const _XmltvRepositorySource({
    required this.sourceId,
    required this.priority,
    required this.revision,
    required this.repository,
  });

  final String sourceId;
  final int priority;
  final String revision;
  final CompactEpgRepository repository;
}
