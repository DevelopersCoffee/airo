import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/presentation/widgets/epg_match_override_sheet.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.com/stream.m3u8',
    group: 'News',
  );

  Future<ProviderContainer> buildContainer() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  testWidgets(
    'shows the channel id as the default match when no override is set',
    (tester) async {
      final container = await buildContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: EpgMatchOverrideSheet(channel: channel)),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('channel-1'), findsWidgets);
    },
  );

  testWidgets('entering an id and tapping Save persists the override', (
    tester,
  ) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: EpgMatchOverrideSheet(channel: channel)),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'manual.epg.id');
    await tester.tap(find.text('Save'));
    await tester.pump();

    final resolved = await container
        .read(epgChannelMatchOverrideStoreProvider)
        .resolveEpgChannelId('channel-1');
    expect(resolved, 'manual.epg.id');
  });

  testWidgets('tapping Clear removes an existing override', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await container
        .read(epgChannelMatchOverrideStoreProvider)
        .setOverride(channelId: 'channel-1', epgChannelId: 'manual.epg.id');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: EpgMatchOverrideSheet(channel: channel)),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Clear override'));
    await tester.pump();

    final resolved = await container
        .read(epgChannelMatchOverrideStoreProvider)
        .resolveEpgChannelId('channel-1');
    expect(resolved, isNull);
  });
}
