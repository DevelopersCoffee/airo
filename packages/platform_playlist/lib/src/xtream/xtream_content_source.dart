import 'package:platform_channels/platform_channels.dart';

import '../content_source.dart';
import 'xtream_client.dart';

class XtreamContentSource extends ContentSource {
  const XtreamContentSource({
    required super.id,
    required super.label,
    required this.serverUrl,
    required this.credentialRef,
  }) : super(
         capabilities: const ContentSourceCapabilities(
           hasEpg: true,
           hasVod: true,
           hasCatchup: false,
         ),
       );

  final String serverUrl;
  final ContentSourceCredentialRef credentialRef;

  @override
  ContentSourceKind get kind => ContentSourceKind.xtream;

  @override
  List<Object?> get props => [...super.props, serverUrl, credentialRef];
}

/// Maps Xtream live streams into [IPTVChannel]s. VOD listing follows the
/// same shape via [XtreamClient.getVodStreams] but is surfaced separately
/// by CV-019 (local VOD listing over BYOC sources), not this adapter.
class XtreamContentSourceAdapter {
  XtreamContentSourceAdapter(this._client);

  final XtreamClient _client;

  Future<List<IPTVChannel>> loadChannels() async {
    final streams = await _client.getLiveStreams();
    return [
      for (final stream in streams)
        IPTVChannel(
          id: 'xtream-${stream.streamId}',
          name: stream.name,
          streamUrl: _client.liveStreamUrl(stream.streamId),
          logoUrl: stream.streamIcon,
          group: stream.categoryId ?? 'Uncategorized',
          tvgId: int.tryParse(stream.epgChannelId ?? ''),
          tvgName: stream.epgChannelId,
        ),
    ];
  }
}
