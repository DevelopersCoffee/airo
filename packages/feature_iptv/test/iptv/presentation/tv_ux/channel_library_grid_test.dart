import 'package:feature_iptv/application/providers/channel_filters_provider.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/channel_library_grid.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('TV action adds and removes channels from multiview', (
    tester,
  ) async {
    IPTVChannel? toggled;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(
              channels: channels,
              metadataByChannelId: const {},
              multiviewChannelIds: const {'two'},
              onMultiviewToggle: (channel) => toggled = channel,
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Add to multiview'), findsOneWidget);
    expect(find.byTooltip('Remove from multiview'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('channel-multiview-one')));
    await tester.pump();

    expect(toggled?.id, 'one');
  });

  testWidgets('one D-pad press moves exactly one channel tile', (tester) async {
    final gridChannels = List<IPTVChannel>.generate(
      5,
      (index) => IPTVChannel(
        id: 'channel-$index',
        name: 'Channel $index',
        streamUrl: 'https://example.com/$index.m3u8',
        group: 'General',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(
              channels: gridChannels,
              metadataByChannelId: const {},
              onChannelSelected: (_) {},
              onMultiviewToggle: (_) {},
            ),
          ),
        ),
      ),
    );

    final cards = find.byType(MediaCard);
    final firstTile = find.byKey(const ValueKey('channel-tile-channel-0'));
    final tileFocusStops = tester
        .widgetList<Focus>(
          find.descendant(of: firstTile, matching: find.byType(Focus)),
        )
        .where(
          (focus) =>
              focus.focusNode != null && focus.focusNode!.canRequestFocus,
        );
    expect(
      tileFocusStops,
      hasLength(1),
      reason: 'A channel box must contribute exactly one D-pad focus stop',
    );
    final firstCardFocus = tester.widget<Focus>(
      find.descendant(of: cards.at(0), matching: find.byType(Focus)).first,
    );
    final secondCardFocus = tester.widget<Focus>(
      find.descendant(of: cards.at(1), matching: find.byType(Focus)).first,
    );
    firstCardFocus.focusNode!.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(
      secondCardFocus.focusNode!.hasFocus,
      isTrue,
      reason: 'RIGHT must move from channel 0 directly to channel 1',
    );
  });

  testWidgets('settled TV focus selects one channel after the dwell delay', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(
              channels: channels,
              metadataByChannelId: const {},
              focusPlayDelay: const Duration(milliseconds: 1200),
              onChannelSelected: (channel) => selected.add(channel.id),
            ),
          ),
        ),
      ),
    );

    final firstCardFocus = tester.widget<Focus>(
      find
          .descendant(
            of: find.byType(MediaCard).at(0),
            matching: find.byType(Focus),
          )
          .first,
    );
    firstCardFocus.focusNode!.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1199));
    expect(selected, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(selected, ['one']);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(selected, ['one'], reason: 'dwell must activate only once');
  });

  testWidgets('moving focus cancels the old channel dwell timer', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(
              channels: channels,
              metadataByChannelId: const {},
              focusPlayDelay: const Duration(milliseconds: 1200),
              onChannelSelected: (channel) => selected.add(channel.id),
            ),
          ),
        ),
      ),
    );

    final cards = find.byType(MediaCard);
    final firstCardFocus = tester.widget<Focus>(
      find.descendant(of: cards.at(0), matching: find.byType(Focus)).first,
    );
    final secondCardFocus = tester.widget<Focus>(
      find.descendant(of: cards.at(1), matching: find.byType(Focus)).first,
    );
    firstCardFocus.focusNode!.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    secondCardFocus.focusNode!.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1199));
    expect(selected, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(selected, ['two']);
  });

  testWidgets('CENTER selects immediately and cancels delayed activation', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(
              channels: channels,
              metadataByChannelId: const {},
              focusPlayDelay: const Duration(milliseconds: 1200),
              onChannelSelected: (channel) => selected.add(channel.id),
            ),
          ),
        ),
      ),
    );

    final firstCardFocus = tester.widget<Focus>(
      find
          .descendant(
            of: find.byType(MediaCard).at(0),
            matching: find.byType(Focus),
          )
          .first,
    );
    firstCardFocus.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(selected, ['one']);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(selected, ['one']);
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

  testWidgets('availability dot renders for checked channels', (tester) async {
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
