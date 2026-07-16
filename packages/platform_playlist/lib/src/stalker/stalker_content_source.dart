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
           hasEpg: true,
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
/// `loadChannels` resolves every channel's `create_link` eagerly and
/// sequentially, which does not scale to portals with hundreds of channels
/// and can produce stale URLs if a resolved link's session token expires
/// before playback. Fine for this issue's scope (no UI consumes this yet),
/// but whoever wires this into CV-022 should resolve `create_link` lazily
/// at play time instead of up front here.
class StalkerContentSourceAdapter {
  StalkerContentSourceAdapter(this._client);

  final StalkerClient _client;

  Future<List<IPTVChannel>> loadChannels() async {
    final token = await _client.handshake();
    final channels = await _client.getChannels(token: token);

    final result = <IPTVChannel>[];
    for (final channel in channels) {
      final url = await _client.createLink(token: token, cmd: channel.cmd);
      result.add(
        IPTVChannel(
          id: 'stalker-${channel.id}',
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
