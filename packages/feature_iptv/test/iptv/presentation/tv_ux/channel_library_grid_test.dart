import 'package:feature_iptv/application/providers/channel_filters_provider.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/channel_library_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_streams/platform_streams.dart';

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

  testWidgets('grid renders every channel as a tile with sort chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(
              channels: channels,
              metadataByChannelId: {
                'one': ChannelBrowseMetadata(country: 'IN', language: 'en'),
                'two': ChannelBrowseMetadata(country: 'US', language: 'en'),
              },
              availabilityByChannelId: {
                'one': StreamAvailability.available,
                'two': StreamAvailability.unavailable,
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    expect(find.byKey(const ValueKey('channel-tile-one')), findsOneWidget);
    expect(find.byKey(const ValueKey('channel-tile-two')), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
    expect(find.text('ABC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a tile invokes onChannelSelected', (tester) async {
    IPTVChannel? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(
              channels: channels,
              metadataByChannelId: const {},
              onChannelSelected: (channel) => tapped = channel,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('One'));
    await tester.pump();

    expect(tapped?.id, 'one');
  });

  testWidgets('sort chip tap invokes onSort with the tapped column', (
    tester,
  ) async {
    ChannelSortColumn? sorted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(
              channels: channels,
              metadataByChannelId: const {},
              onSort: (column) => sorted = column,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Category'));
    await tester.pump();

    expect(sorted, ChannelSortColumn.category);
  });

  testWidgets('reports the currently visible channels for bounded scanning', (
    tester,
  ) async {
    final manyChannels = List<IPTVChannel>.generate(
      40,
      (index) => IPTVChannel(
        id: 'channel-$index',
        name: 'Channel $index',
        streamUrl: 'https://example.com/$index.m3u8',
        group: 'General',
      ),
    );
    var visibleIds = const <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 260,
            child: ChannelLibraryGrid(
              channels: manyChannels,
              metadataByChannelId: const {},
              onVisibleChannelsChanged: (channels) {
                visibleIds = channels.map((channel) => channel.id).toList();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(visibleIds, contains('channel-0'));
    expect(visibleIds.length, lessThan(manyChannels.length));
  });

  testWidgets('large grid scrolls tiles into view', (tester) async {
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
            height: 500,
            child: ChannelLibraryGrid(
              channels: manyChannels,
              metadataByChannelId: const {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Channel 0'), findsOneWidget);
    expect(find.text('Channel 119'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Channel 119'),
      620,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Channel 119'), findsOneWidget);
  });

  testWidgets('availability dot renders for checked channels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(
              channels: channels,
              metadataByChannelId: {},
              availabilityByChannelId: {
                'one': StreamAvailability.available,
                'two': StreamAvailability.restricted,
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Channel reachable'), findsOneWidget);
    expect(find.byTooltip('Channel may be restricted'), findsOneWidget);
  });
}
