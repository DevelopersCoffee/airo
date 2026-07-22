import 'dart:async';

import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/last_channel_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

IPTVChannel channel(String id, {String name = 'Test'}) => IPTVChannel(
  id: id,
  name: name,
  streamUrl: 'https://example.com/$id.m3u8',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('findResumeChannel', () {
    final channels = [channel('aajtak'), channel('bbc-earth')];

    test('returns the matching channel by id', () {
      final result = findResumeChannel(
        lastChannelId: 'bbc-earth',
        channels: channels,
      );

      expect(result?.id, 'bbc-earth');
    });

    test('returns null when id is null', () {
      expect(findResumeChannel(lastChannelId: null, channels: channels), isNull);
    });

    test('returns null when the channel is gone from the list', () {
      expect(
        findResumeChannel(lastChannelId: 'gone', channels: channels),
        isNull,
      );
    });

    test('returns null for an empty channel list', () {
      expect(
        findResumeChannel(lastChannelId: 'aajtak', channels: const []),
        isNull,
      );
    });
  });

  group('lastChannelRecorderProvider', () {
    test('persists a new current channel', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final states = StreamController<StreamingState>.broadcast();
      addTearDown(states.close);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          streamingStateStreamProvider.overrideWithValue(states.stream),
        ],
      );
      addTearDown(container.dispose);

      container.read(lastChannelRecorderProvider);
      states.add(StreamingState(currentChannel: channel('aajtak')));
      await Future<void>.delayed(Duration.zero);

      expect(preferences.getString(iptvLastChannelKey), 'aajtak');
    });
  });

  group('resumeChannelProvider', () {
    test('resolves stored id against the channel list', () async {
      SharedPreferences.setMockInitialValues({iptvLastChannelKey: 'bbc-earth'});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          iptvChannelsProvider.overrideWith(
            (ref) async => [channel('aajtak'), channel('bbc-earth')],
          ),
        ],
      );
      addTearDown(container.dispose);

      final resumed = await container.read(resumeChannelProvider.future);

      expect(resumed?.id, 'bbc-earth');
    });

    test('yields null when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          iptvChannelsProvider.overrideWith((ref) async => [channel('aajtak')]),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(resumeChannelProvider.future), isNull);
    });
  });
}
