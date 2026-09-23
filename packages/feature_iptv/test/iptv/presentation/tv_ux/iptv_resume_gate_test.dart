import 'dart:async';

import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/last_channel_provider.dart';
import 'package:feature_iptv/application/resume_last_channel_controller.dart';
import 'package:feature_iptv/presentation/tv_ux/iptv_resume_gate.dart';
import 'package:feature_iptv/presentation/tv_ux/iptv_resume_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';

IPTVChannel channel(String id) =>
    IPTVChannel(id: id, name: id, streamUrl: 'https://example.com/$id.m3u8');

final testPlaybackStateProvider = StateProvider<PlaybackState>(
  (ref) => PlaybackState.idle,
);

void main() {
  Widget harness(
    List<Override> overrides, {
    bool holdUntilTerminal = false,
    VoidCallback? onEnterWatch,
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: IptvResumeGate(
          holdUntilTerminal: holdUntilTerminal,
          onEnterWatch: onEnterWatch,
          child: const Text('BROWSE'),
        ),
      ),
    );
  }

  testWidgets('no resume target reveals browse without a splash hold', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness([resumeChannelProvider.overrideWith((ref) async => null)]),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(IptvResumeSplash), findsNothing);
    expect(find.text('BROWSE'), findsOneWidget);
  });

  testWidgets('resume target shows splash then dismisses at cap', (
    tester,
  ) async {
    final played = <String>[];
    await tester.pumpWidget(
      harness([
        resumeChannelProvider.overrideWith((ref) async => channel('aajtak')),
        playChannelDelegateProvider.overrideWithValue((channel) async {
          played.add(channel.id);
        }),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(played, ['aajtak']);
    expect(find.byType(IptvResumeSplash), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.pump();
    expect(find.byType(IptvResumeSplash), findsNothing);
  });

  testWidgets(
    'playback readiness after min display dismisses splash without provider mutation during build',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          resumeChannelProvider.overrideWith((ref) async => channel('aajtak')),
          playChannelDelegateProvider.overrideWithValue((channel) async {}),
          playbackStateProvider.overrideWith(
            (ref) => ref.watch(testPlaybackStateProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: IptvResumeGate(child: Text('BROWSE'))),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(IptvResumeSplash), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      container.read(testPlaybackStateProvider.notifier).state =
          PlaybackState.playing;
      await tester.pump();

      expect(tester.takeException(), isNull);
      await tester.pump();
      expect(find.byType(IptvResumeSplash), findsNothing);
    },
  );

  testWidgets('splash never returns after no-target dismissal', (tester) async {
    await tester.pumpWidget(
      harness([resumeChannelProvider.overrideWith((ref) async => null)]),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));

    expect(find.byType(IptvResumeSplash), findsNothing);
  });

  testWidgets('does not replay a completed splash after the gate remounts', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        resumeChannelProvider.overrideWith((ref) async => channel('aajtak')),
        playChannelDelegateProvider.overrideWithValue((channel) async {}),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: IptvResumeGate(child: Text('BROWSE'))),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    await tester.pump();
    expect(find.byType(IptvResumeSplash), findsNothing);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: IptvResumeGate(child: Text('BROWSE'))),
      ),
    );
    await tester.pump();

    expect(find.byType(IptvResumeSplash), findsNothing);
  });

  testWidgets('disabled gate does not start a resume attempt', (tester) async {
    final played = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resumeChannelProvider.overrideWith((ref) async => channel('aajtak')),
          playChannelDelegateProvider.overrideWithValue((channel) async {
            played.add(channel.id);
          }),
        ],
        child: const MaterialApp(
          home: IptvResumeGate(enabled: false, child: Text('BROWSE')),
        ),
      ),
    );
    await tester.pump();

    expect(played, isEmpty);
    expect(find.byType(IptvResumeSplash), findsNothing);
    expect(find.text('BROWSE'), findsOneWidget);
  });

  testWidgets(
    'holdUntilTerminal keeps splash after cap while lookup is still pending',
    (tester) async {
      final completer = Completer<IPTVChannel?>();
      await tester.pumpWidget(
        harness([
          resumeChannelProvider.overrideWith((ref) => completer.future),
          playChannelDelegateProvider.overrideWithValue((channel) async {}),
        ], holdUntilTerminal: true),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(IptvResumeSplash), findsOneWidget);

      await tester.pump(const Duration(seconds: 7));
      expect(find.byType(IptvResumeSplash), findsOneWidget);

      completer.complete(null);
      await tester.pump();
      await tester.pump();
      expect(find.byType(IptvResumeSplash), findsNothing);
    },
  );

  testWidgets('onEnterWatch fires once when done splash dismisses', (
    tester,
  ) async {
    var entered = 0;
    await tester.pumpWidget(
      harness(
        [
          resumeChannelProvider.overrideWith((ref) async => channel('aajtak')),
          playChannelDelegateProvider.overrideWithValue((channel) async {}),
        ],
        holdUntilTerminal: true,
        onEnterWatch: () => entered++,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    await tester.pump();

    expect(entered, 1);
    expect(find.byType(IptvResumeSplash), findsNothing);
  });

  testWidgets('noTarget never calls onEnterWatch', (tester) async {
    var entered = 0;
    await tester.pumpWidget(
      harness(
        [resumeChannelProvider.overrideWith((ref) async => null)],
        holdUntilTerminal: true,
        onEnterWatch: () => entered++,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));

    expect(entered, 0);
    expect(find.byType(IptvResumeSplash), findsNothing);
  });

  testWidgets('skip before done never calls onEnterWatch later', (
    tester,
  ) async {
    final completer = Completer<IPTVChannel?>();
    var entered = 0;
    await tester.pumpWidget(
      harness(
        [
          resumeChannelProvider.overrideWith((ref) => completer.future),
          playChannelDelegateProvider.overrideWithValue((channel) async {}),
        ],
        holdUntilTerminal: true,
        onEnterWatch: () => entered++,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(IptvResumeSplash), findsOneWidget);

    await tester.tap(find.byType(IptvResumeSplash));
    await tester.pump();
    expect(find.byType(IptvResumeSplash), findsNothing);
    expect(entered, 0);

    completer.complete(channel('aajtak'));
    await tester.pump();
    await tester.pump();
    expect(entered, 0);
  });
}
