import 'package:platform_channels/platform_channels.dart';

import 'content_source_store.dart';

/// Applies per-source default stream headers when a channel has none.
IPTVChannel applySourceStreamHeaders({
  required IPTVChannel channel,
  required ContentSourceConfig source,
}) {
  final userAgent = source.streamUserAgent?.trim();
  final referrer = source.streamReferrer?.trim();
  if ((userAgent == null || userAgent.isEmpty) &&
      (referrer == null || referrer.isEmpty)) {
    return channel;
  }
  final existing = channel.headers;
  return channel.copyWith(
    headers: ChannelHeaders(
      userAgent: existing?.userAgent ?? userAgent,
      referrer: existing?.referrer ?? referrer,
    ),
  );
}

List<IPTVChannel> applySourceStreamHeadersToAll({
  required List<IPTVChannel> channels,
  required ContentSourceConfig source,
}) {
  return [
    for (final channel in channels)
      applySourceStreamHeaders(channel: channel, source: source),
  ];
}
