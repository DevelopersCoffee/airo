import 'package:feature_iptv/application/providers/channel_filters_provider.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/channel_table.dart';
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
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('Country'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.byKey(const ValueKey('channel-row-one')), findsOneWidget);
  });
}
