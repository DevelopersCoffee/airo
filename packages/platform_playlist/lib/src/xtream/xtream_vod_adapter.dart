import 'package:platform_channels/platform_channels.dart';

import 'xtream_client.dart';

/// Maps Xtream VOD streams into [VodItem]s. All Xtream VOD entries are
/// standalone movies from this adapter's perspective — Xtream's separate
/// series API (`get_series`) is out of scope for this issue; series
/// grouping for Xtream sources happens via the same title-parsing
/// heuristic `feature_iptv` applies to M3U (see CV-019's series/episode
/// grouping step), not a second Xtream-specific code path.
class XtreamVodAdapter {
  XtreamVodAdapter(this._client);

  final XtreamClient _client;

  Future<List<VodItem>> loadVodItems() async {
    final streams = await _client.getVodStreams();
    return [
      for (final stream in streams)
        VodItem(
          id: 'xtream-vod-${stream.streamId}',
          title: stream.name,
          streamUrl: _client.vodStreamUrl(
            stream.streamId,
            stream.containerExtension ?? 'mp4',
          ),
          posterUrl: stream.streamIcon,
          group: stream.categoryId ?? 'Uncategorized',
          kind: VodContentKind.movie,
          containerExtension: stream.containerExtension ?? 'mp4',
        ),
    ];
  }
}
