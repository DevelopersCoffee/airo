import 'package:platform_channels/platform_channels.dart';

import '../content_source.dart';
import 'stalker_client.dart';

/// Stalker Portal (Ministra middleware) source.
///
/// Identifies the device by MAC address rather than username/password — the
/// `mac` cookie *is* the credential. [macAddress] is stored directly (not a
/// secret needing [ContentSourceCredentialStore] redaction — MAC addresses
/// are device identifiers already visible elsewhere in this repo, e.g.
/// `core_device_identity`). Only the session token returned by
/// [StalkerClient.handshake] is short-lived/sensitive, and it is kept in
/// memory only (never stored on this class).
class StalkerContentSource extends ContentSource {
  const StalkerContentSource({
    required super.id,
    required super.label,
    required this.serverUrl,
    required this.macAddress,
  }) : super(
         capabilities: const ContentSourceCapabilities(
           hasEpg: false,
           hasVod: false,
           hasCatchup: false,
         ),
       );

  final String serverUrl;
  final String macAddress;

  @override
  ContentSourceKind get kind => ContentSourceKind.stalker;

  @override
  List<Object?> get props => [...super.props, serverUrl, macAddress];
}

/// Resolves each Stalker channel's play URL via `create_link` — Stalker's
/// `cmd` field from the channel list is a middleware-internal command, not
/// a directly playable stream URL.
///
/// `loadChannels` currently resolves each link sequentially because
/// [IPTVChannel] requires a playable URL. This bounded v1 path preserves
/// provider ordering and avoids request bursts; a future platform-playlist
/// contract can add opaque lazy resolvers without leaking Stalker behavior
/// into the player package.
class StalkerContentSourceAdapter {
  StalkerContentSourceAdapter(this._client, {this.sourceId = 'stalker'});

  final StalkerClient _client;
  final String sourceId;

  Future<List<IPTVChannel>> loadChannels() async {
    final token = await _client.handshake();
    final channels = await _client.getChannels(token: token);

    final result = <IPTVChannel>[];
    for (final channel in channels) {
      final url = await _client.createLink(token: token, cmd: channel.cmd);
      result.add(
        IPTVChannel(
          id: '$sourceId-${channel.id}',
          name: channel.name,
          streamUrl: url,
          logoUrl: channel.logo,
          group: channel.genreId ?? 'Uncategorized',
        ),
      );
    }
    return result;
  }
}
