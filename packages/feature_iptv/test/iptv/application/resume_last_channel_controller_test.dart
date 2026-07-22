import 'package:feature_iptv/application/providers/last_channel_provider.dart';
import 'package:feature_iptv/application/resume_last_channel_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

IPTVChannel channel(String id) => IPTVChannel(
  id: id,
  name: id,
  streamUrl: 'https://example.com/$id.m3u8',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer({
    IPTVChannel? resumeTarget,
    required List<String> playedIds,
    bool playThrows = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        resumeChannelProvider.overrideWith((ref) async => resumeTarget),
        playChannelDelegateProvider.overrideWithValue((channel) async {
          playedIds.add(channel.id);
          if (playThrows) throw StateError('boom');
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('tunes resume target and lands in done', () async {
    final played = <String>[];
    final container = makeContainer(
      resumeTarget: channel('aajtak'),
      playedIds: played,
    );

    await container
        .read(resumeLastChannelControllerProvider.notifier)
        .attemptResume();

    expect(played, ['aajtak']);
    expect(container.read(resumeLastChannelControllerProvider), ResumeStatus.done);
  });

  test('no stored target lands in noTarget without tuning', () async {
    final played = <String>[];
    final container = makeContainer(resumeTarget: null, playedIds: played);

    await container
        .read(resumeLastChannelControllerProvider.notifier)
        .attemptResume();

    expect(played, isEmpty);
    expect(
      container.read(resumeLastChannelControllerProvider),
      ResumeStatus.noTarget,
    );
  });

  test('second resume attempt is a no-op', () async {
    final played = <String>[];
    final container = makeContainer(
      resumeTarget: channel('aajtak'),
      playedIds: played,
    );
    final controller = container.read(
      resumeLastChannelControllerProvider.notifier,
    );

    await controller.attemptResume();
    await controller.attemptResume();

    expect(played, ['aajtak']);
  });

  test('play failure lands in failed without a retry', () async {
    final played = <String>[];
    final container = makeContainer(
      resumeTarget: channel('aajtak'),
      playedIds: played,
      playThrows: true,
    );

    await container
        .read(resumeLastChannelControllerProvider.notifier)
        .attemptResume();

    expect(played, ['aajtak']);
    expect(
      container.read(resumeLastChannelControllerProvider),
      ResumeStatus.failed,
    );
  });
}
