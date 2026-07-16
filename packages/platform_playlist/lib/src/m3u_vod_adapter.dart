import 'package:platform_channels/platform_channels.dart';

/// Best-effort extraction of VOD-shaped entries from an M3U-parsed channel
/// list. M3U has no formal on-demand/live distinction (see CV-019's plan
/// notes) — this treats a channel as VOD when [IPTVChannel.category] is
/// already inferred as [ChannelCategory.movies], or its [IPTVChannel.group]
/// mentions "vod" or "series" (case-insensitive), matching the group-title
/// convention BYOC M3U providers commonly use to mark on-demand content.
class M3uVodAdapter {
  List<VodItem> extractVodItems(List<IPTVChannel> channels) {
    return [
      for (final channel in channels)
        if (_isVodShaped(channel))
          VodItem(
            id: channel.id,
            title: channel.name,
            streamUrl: channel.streamUrl,
            posterUrl: channel.logoUrl,
            group: channel.group,
            kind: VodContentKind.movie,
          ),
    ];
  }

  bool _isVodShaped(IPTVChannel channel) {
    if (channel.category == ChannelCategory.movies) return true;
    final group = channel.group.toLowerCase();
    return group.contains('vod') || group.contains('series');
  }
}
