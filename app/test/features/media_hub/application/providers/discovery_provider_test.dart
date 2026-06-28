import 'package:airo_app/features/iptv/application/providers/iptv_providers.dart';
import 'package:airo_app/features/iptv/domain/models/iptv_channel.dart';
import 'package:airo_app/features/media_hub/application/providers/discovery_provider.dart';
import 'package:airo_app/features/media_hub/domain/models/media_mode.dart';
import 'package:airo_app/features/music/application/providers/music_tracks_provider.dart';
import 'package:airo_app/features/music/domain/services/music_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps music tracks into unified discovery content', () async {
    const tracks = [
      MusicTrack(
        id: 'track-1',
        title: 'Track',
        artist: 'Artist',
        duration: Duration(minutes: 3),
        streamUrl: 'https://example.com/audio.mp3',
      ),
    ];
    final container = ProviderContainer(
      overrides: [musicTracksProvider.overrideWith((ref) async => tracks)],
    );
    addTearDown(container.dispose);

    await container.read(musicTracksProvider.future);
    final data =
        container.read(mediaHubDiscoveryProvider(MediaMode.music)).value ?? [];

    expect(data, hasLength(1));
    expect(data.first.mode, MediaMode.music);
    expect(data.first.title, 'Track');
  });

  test('maps tv channels into unified discovery content', () async {
    const channels = [
      IPTVChannel(
        id: 'tv-1',
        name: 'Airo TV',
        streamUrl: 'https://example.com/live.m3u8',
        group: 'General',
        category: ChannelCategory.general,
      ),
    ];
    final container = ProviderContainer(
      overrides: [iptvChannelsProvider.overrideWith((ref) async => channels)],
    );
    addTearDown(container.dispose);

    await container.read(iptvChannelsProvider.future);
    final data =
        container.read(mediaHubDiscoveryProvider(MediaMode.tv)).value ?? [];

    expect(data, hasLength(1));
    expect(data.first.mode, MediaMode.tv);
    expect(data.first.title, 'Airo TV');
  });
}
