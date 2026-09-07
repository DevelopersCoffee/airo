import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/application/channel_share.dart';
import 'package:feature_iptv/application/iptv_deep_link.dart';
import 'package:feature_iptv/application/providers/channel_filters_provider.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/channel_info_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.test/stream.m3u8',
  );

  testWidgets(
    'favorite action persists and reflects the active channel state',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ChannelInfoBar(channel: channel)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Favorite'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.byTooltip('Favorite'));
      await tester.pumpAndSettle();

      expect(preferences.getStringList('iptv_favorite_channel_ids'), [
        'channel-1',
      ]);
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await tester.tap(find.byTooltip('Remove from favorites'));
      await tester.pumpAndSettle();

      expect(preferences.getStringList('iptv_favorite_channel_ids'), isEmpty);
      expect(find.byTooltip('Favorite'), findsOneWidget);
    },
  );

  testWidgets(
    'compact defaults to false, keeping the original single-line ten-foot header',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ChannelInfoBar(channel: channel)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Original ten-foot presentation: a plain Chip carries the LIVE
      // label, not the compact editorial AiroBadge pill.
      expect(find.byType(Chip), findsOneWidget);
      expect(find.widgetWithText(Chip, 'LIVE'), findsOneWidget);
      expect(find.byType(AiroBadge), findsNothing);
    },
  );

  testWidgets(
    'compact: true renders the two-line editorial header instead of the Chip',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ChannelInfoBar(channel: channel, compact: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Chip), findsNothing);
      expect(find.byType(AiroBadge), findsOneWidget);
      expect(find.text('Example Channel'), findsOneWidget);
    },
  );

  testWidgets('favorite action is disabled until a channel is selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ChannelInfoBar())),
      ),
    );

    final button = tester.widget<IconButton>(find.byType(IconButton).first);
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'share sends a playable friend message and no placeholder actions remain',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final gateway = _RecordingShareGateway();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            channelShareGatewayProvider.overrideWithValue(gateway),
            channelShareMessageComposerProvider.overrideWithValue(
              ChannelShareMessageComposer(selectTemplate: (_) => 0),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ChannelInfoBar(channel: channel)),
          ),
        ),
      );

      expect(find.byTooltip('Like'), findsNothing);
      expect(find.byTooltip('Ways to watch'), findsNothing);
      expect(find.byTooltip('Share'), findsOneWidget);

      await tester.tap(find.byTooltip('Share'));
      await tester.pump();

      expect(gateway.subject, 'Watch Example Channel in Airo');
      expect(gateway.text, contains('You bring the snacks'));
      expect(gateway.text, contains('Example Channel'));
      final link = _linkFrom(gateway.text!);
      final parsed = IptvDeepLinkIntent.tryParse(link);
      expect(parsed?.canImport, isTrue);
      expect(parsed?.streamUrl.toString(), channel.streamUrl);
      expect(find.text('Example Channel ready to share'), findsOneWidget);
    },
  );

  testWidgets('share includes the active filter combination', (tester) async {
    SharedPreferences.setMockInitialValues({
      channelFilterSearchStorageKey: 'local news',
      channelFilterCountryStorageKey: 'in',
    });
    final preferences = await SharedPreferences.getInstance();
    final gateway = _RecordingShareGateway();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          channelShareGatewayProvider.overrideWithValue(gateway),
          channelShareMessageComposerProvider.overrideWithValue(
            ChannelShareMessageComposer(selectTemplate: (_) => 0),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChannelInfoBar(channel: channel)),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Share'));
    await tester.pump();

    final parsed = IptvDeepLinkIntent.tryParse(_linkFrom(gateway.text!));
    expect(parsed?.channelId, channel.id);
    expect(parsed?.filters.search, 'local news');
    expect(parsed?.filters.country, 'in');
  });
}

Uri _linkFrom(String message) {
  final match = RegExp(r'https://\S+').firstMatch(message);
  return Uri.parse(match!.group(0)!);
}

final class _RecordingShareGateway implements ChannelShareGateway {
  String? subject;
  String? text;

  @override
  Future<bool> share({required String subject, required String text}) async {
    this.subject = subject;
    this.text = text;
    return true;
  }
}
