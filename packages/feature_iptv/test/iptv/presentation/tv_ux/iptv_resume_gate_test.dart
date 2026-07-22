import 'package:feature_iptv/application/providers/last_channel_provider.dart';
import 'package:feature_iptv/application/resume_last_channel_controller.dart';
import 'package:feature_iptv/presentation/tv_ux/iptv_resume_gate.dart';
import 'package:feature_iptv/presentation/tv_ux/iptv_resume_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

IPTVChannel channel(String id) =>
    IPTVChannel(id: id, name: id, streamUrl: 'https://example.com/$id.m3u8');

void main() {
  Widget harness(List<Override> overrides) {
    return ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: IptvResumeGate(child: Text('BROWSE'))),
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
}
