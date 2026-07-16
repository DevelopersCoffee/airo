import 'package:platform_channels/platform_channels.dart';

import '../content_source.dart';
import 'jellyfin_client.dart';

class JellyfinContentSource extends ContentSource {
  const JellyfinContentSource({
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
  ContentSourceKind get kind => ContentSourceKind.jellyfin;

  @override
  List<Object?> get props => [...super.props, serverUrl, credentialRef];
}

class JellyfinContentSourceAdapter {
  JellyfinContentSourceAdapter(this._client);

  final JellyfinClient _client;

  Future<List<IPTVChannel>> loadChannels() async {
    final auth = await _client.authenticate();
    final channels = await _client.getLiveTvChannels(
      accessToken: auth.accessToken,
      userId: auth.userId,
    );

    return [
      for (final channel in channels)
        IPTVChannel(
          id: 'jellyfin-${channel.id}',
          name: channel.name,
          streamUrl: _client.streamUrl(channel.id, auth.accessToken),
          tvgName: channel.number,
        ),
    ];
  }
}
