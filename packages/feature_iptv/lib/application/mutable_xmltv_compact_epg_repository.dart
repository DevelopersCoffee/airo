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
  MutableXmltvCompactEpgRepository({CompactEpgRepository? initial})
    : _inner = initial ?? const EmptyCompactEpgRepository();

  CompactEpgRepository _inner;

  /// Swaps the delegate. Pass `null` to revert to unavailable (e.g. when a
  /// source is removed).
  void updateSource(CompactEpgRepository? repository) {
    _inner = repository ?? const EmptyCompactEpgRepository();
  }

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) => _inner.loadCurrentNext(channelIds: channelIds, now: now);

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) =>
      _inner.loadWindow(query);
}
