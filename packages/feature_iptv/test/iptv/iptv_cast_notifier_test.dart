import "package:feature_iptv/feature_iptv.dart";
import "package:platform_channels/platform_channels.dart";
import "package:platform_player/platform_player.dart";
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tv = AiroCastDevice(id: 'tv-1', name: 'Sony Bravia');

  IPTVChannel channel() => const IPTVChannel(
    id: 'p4u',
    name: 'P4U Music',
    streamUrl: 'https://example.com/live.m3u8',
    group: 'Music',
    category: ChannelCategory.music,
  );

  ProviderContainer containerWith(FakeAiroCastController fake) {
    final container = ProviderContainer(
      overrides: [airoCastControllerProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts discovery through controller', () async {
    final fake = FakeAiroCastController(devices: const [tv]);
    final container = containerWith(fake);

    await container.read(iptvCastProvider.notifier).startDiscovery();

    expect(fake.recordedActions, contains('startDiscovery'));
    expect(
      container.read(iptvCastProvider).discovery.phase,
      AiroCastDiscoveryPhase.found,
    );
  });

  test('casts a channel to selected device', () async {
    final fake = FakeAiroCastController(devices: const [tv]);
    final container = containerWith(fake);

    await container
        .read(iptvCastProvider.notifier)
        .castChannelToDevice(channel: channel(), device: tv);

    expect(fake.recordedActions, [
      'connect:tv-1',
      'load:https://example.com/live.m3u8',
    ]);
    expect(
      container.read(iptvCastProvider).session.phase,
      AiroCastSessionPhase.playing,
    );
  });

  test('stores unsupported stream error without connecting', () async {
    final fake = FakeAiroCastController(devices: const [tv]);
    final container = containerWith(fake);

    await container
        .read(iptvCastProvider.notifier)
        .castChannelToDevice(
          channel: channel().copyWith(
            headers: const ChannelHeaders(userAgent: 'Airo'),
          ),
          device: tv,
        );

    expect(fake.recordedActions, isEmpty);
    expect(
      container.read(iptvCastProvider).lastError?.code,
      AiroCastErrorCode.unsupportedStream,
    );
  });

  test('casts a new channel to the active device', () async {
    final fake = FakeAiroCastController(devices: const [tv]);
    final container = containerWith(fake);
    final notifier = container.read(iptvCastProvider.notifier);

    await notifier.castChannelToDevice(channel: channel(), device: tv);
    await notifier.castChannelToActiveDevice(
      channel: channel().copyWith(streamUrl: 'https://example.com/next.m3u8'),
    );

    expect(fake.recordedActions, [
      'connect:tv-1',
      'load:https://example.com/live.m3u8',
      'connect:tv-1',
      'load:https://example.com/next.m3u8',
    ]);
    expect(
      container.read(iptvCastProvider).session.media?.url,
      Uri.parse('https://example.com/next.m3u8'),
    );
  });

  test('reports receiver unavailable when no active device exists', () async {
    final fake = FakeAiroCastController(devices: const [tv]);
    final container = containerWith(fake);

    await container
        .read(iptvCastProvider.notifier)
        .castChannelToActiveDevice(channel: channel());

    expect(fake.recordedActions, isEmpty);
    expect(
      container.read(iptvCastProvider).lastError,
      const AiroCastError(
        code: AiroCastErrorCode.receiverUnavailable,
        message: 'Choose a Cast device before casting this channel.',
      ),
    );
  });

  test('captures connection failures from controller', () async {
    final fake = FakeAiroCastController(
      devices: const [tv],
      failConnection: true,
    );
    final container = containerWith(fake);

    await container
        .read(iptvCastProvider.notifier)
        .castChannelToDevice(channel: channel(), device: tv);

    expect(fake.recordedActions, ['connect:tv-1']);
    expect(
      container.read(iptvCastProvider).lastError?.code,
      AiroCastErrorCode.connectionTimeout,
    );
  });
}
