import 'package:platform_channels/platform_channels.dart';

/// Detects a "Show Name S01E02" / "Show Name S1E2" pattern anywhere in a
/// title, capturing season and episode numbers.
final RegExp _seasonEpisodePattern = RegExp(
  r'^(.*?)[\s\-]*S(\d{1,2})E(\d{1,2})\b',
  caseSensitive: false,
);

/// Applies a best-effort series/episode grouping heuristic to [VodItem]s
/// parsed from BYOC sources with no formal series metadata. See CV-019:
/// no third-party lookup, title-pattern matching only.
class VodSeriesGrouper {
  /// Returns [item] unchanged if its title doesn't match a season/episode
  /// pattern, or a copy with [VodContentKind.episode] and a populated
  /// [VodItem.seriesRef] if it does.
  VodItem applySeriesRef(VodItem item) {
    final match = _seasonEpisodePattern.firstMatch(item.title);
    if (match == null) return item;

    final seriesTitle = match.group(1)!.trim();
    if (seriesTitle.isEmpty) return item;

    final seasonNumber = int.parse(match.group(2)!);
    final episodeNumber = int.parse(match.group(3)!);

    return VodItem(
      id: item.id,
      title: item.title,
      streamUrl: item.streamUrl,
      posterUrl: item.posterUrl,
      group: item.group,
      kind: VodContentKind.episode,
      containerExtension: item.containerExtension,
      seriesRef: VodSeriesRef(
        seriesId: _slugify(seriesTitle),
        seriesTitle: seriesTitle,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      ),
    );
  }

  List<VodItem> applySeriesRefs(List<VodItem> items) =>
      items.map(applySeriesRef).toList();

  String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}

/// One series and its episodes, sorted by season then episode number.
class VodSeriesGroup {
  const VodSeriesGroup({
    required this.seriesId,
    required this.seriesTitle,
    required this.episodes,
  });

  final String seriesId;
  final String seriesTitle;
  final List<VodItem> episodes;
}

/// Partitions [items] (already passed through [VodSeriesGrouper]) into
/// series groups. Items with [VodContentKind.movie] (no [VodItem.seriesRef])
/// are not included — the caller presents movies and series groups
/// side by side, not nested.
List<VodSeriesGroup> groupVodItemsBySeries(List<VodItem> items) {
  final bySeriesId = <String, List<VodItem>>{};
  final seriesTitleById = <String, String>{};

  for (final item in items) {
    final ref = item.seriesRef;
    if (ref == null) continue;
    (bySeriesId[ref.seriesId] ??= []).add(item);
    seriesTitleById[ref.seriesId] = ref.seriesTitle;
  }

  final groups = [
    for (final entry in bySeriesId.entries)
      VodSeriesGroup(
        seriesId: entry.key,
        seriesTitle: seriesTitleById[entry.key]!,
        episodes: entry.value
          ..sort((a, b) {
            final seasonCompare = (a.seriesRef!.seasonNumber ?? 0)
                .compareTo(b.seriesRef!.seasonNumber ?? 0);
            if (seasonCompare != 0) return seasonCompare;
            return (a.seriesRef!.episodeNumber ?? 0)
                .compareTo(b.seriesRef!.episodeNumber ?? 0);
          }),
      ),
  ];

  return groups;
}
