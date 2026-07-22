import 'package:feature_iptv/application/providers/channel_filters_provider.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/channel_table.dart';
import 'package:feature_iptv/presentation/widgets/channel_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  const channels = [
    IPTVChannel(
      id: 'one',
      name: 'One',
      streamUrl: 'https://one',
      group: 'News',
    ),
    IPTVChannel(
      id: 'two',
      name: 'ABC',
      streamUrl: 'https://two',
      group: 'General',
    ),
  ];

  testWidgets('wide table exposes metadata columns and availability strip', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: ChannelTable(
              channels: channels,
              metadataByChannelId: {
                'one': ChannelBrowseMetadata(country: 'IN', language: 'en'),
                'two': ChannelBrowseMetadata(country: 'US', language: 'en'),
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('Flag'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.byKey(const ValueKey('channel-row-one')), findsOneWidget);
    expect(find.byType(ChannelLogo), findsNWidgets(2));
    expect(find.text('🇮🇳'), findsOneWidget);
    expect(find.text('🇺🇸'), findsOneWidget);
    expect(find.text('🇮🇳 India'), findsNothing);
    expect(find.text('🇺🇸 United States'), findsNothing);
    expect(find.text('English'), findsNWidgets(2));

    expect(
      tester.getCenter(find.text('🇺🇸')).dx,
      greaterThan(tester.getCenter(find.text('English').last).dx),
    );
  });

  testWidgets('compact table keeps channel options visible with small logos', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: ChannelTable(
              channels: [
                IPTVChannel(
                  id: 'one',
                  name: 'One',
                  streamUrl: 'https://one',
                  group: 'News',
                  languages: ['en', 'it'],
                ),
              ],
              metadataByChannelId: {
                'one': ChannelBrowseMetadata(country: 'IT'),
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Flag'), findsOneWidget);
    expect(find.text('Lang.'), findsOneWidget);
    expect(find.text('🇮🇹'), findsOneWidget);
    expect(find.text('🇮🇹 Italy'), findsNothing);
    expect(find.text('English, Italian'), findsOneWidget);
    expect(find.byIcon(Icons.newspaper), findsOneWidget);
    expect(find.byIcon(Icons.live_tv), findsWidgets);
    expect(tester.widget<ChannelLogo>(find.byType(ChannelLogo)).size, 26);
    expect(
      tester.getCenter(find.text('🇮🇹')).dx,
      greaterThan(tester.getCenter(find.text('English, Italian')).dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large channel table scrolls rows while keeping header pinned', (
    tester,
  ) async {
    final manyChannels = List<IPTVChannel>.generate(
      120,
      (index) => IPTVChannel(
        id: 'channel-$index',
        name: 'Channel $index',
        streamUrl: 'https://example.com/$index.m3u8',
        group: index.isEven ? 'General' : 'News',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 260,
            child: ChannelTable(
              channels: manyChannels,
              metadataByChannelId: const {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Channel 0'), findsOneWidget);
    expect(find.text('Channel 119'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Channel 119'),
      620,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Channel 0'), findsNothing);
    expect(find.text('Channel 119'), findsOneWidget);
  });
}
