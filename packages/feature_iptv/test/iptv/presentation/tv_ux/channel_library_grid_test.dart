import 'package:feature_iptv/application/providers/browse_grid_tv_peek_provider.dart';
import 'package:feature_iptv/application/providers/channel_filters_provider.dart';
import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/channel_library_grid.dart';
import 'package:feature_iptv/presentation/widgets/tv_mini_guide_overlay.dart';
import 'package:platform_player/platform_player.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:platform_streams/platform_streams.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(
  WidgetTester tester,
  Widget app, {
  Map<String, String> nowPlaying = const {},
  SharedPreferences? prefs,
  bool tvPeekEnabled = false,
  TvMiniGuidePreviewFactory? previewFactory,
}) async {
  final preferences = prefs ?? await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        browseNowPlayingByChannelIdProvider.overrideWithValue(nowPlaying),
        if (tvPeekEnabled)
          browseGridTvPeekEnabledProvider.overrideWith((ref) {
            final notifier = BrowseGridTvPeekEnabledNotifier(ref);
            notifier.state = true;
            return notifier;
          }),
        if (previewFactory != null)
          tvMiniGuidePreviewFactoryProvider.overrideWithValue(previewFactory),
      ],
      child: app,
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
  });

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

  testWidgets(
    'grid renders every channel as a tile with a compact sort trigger',
    (tester) async {
      await pumpApp(
        tester,
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

      // One compact "Sort: Name" trigger replaces four always-visible chips
      // (#compact-tv-chrome) — the other three columns live inside the
      // sheet it opens, not permanently on screen.
      expect(find.text('Sort: Name'), findsOneWidget);
      expect(find.text('Category'), findsNothing);
      expect(find.byKey(const ValueKey('channel-tile-one')), findsOneWidget);
      expect(find.byKey(const ValueKey('channel-tile-two')), findsOneWidget);
      expect(find.text('One'), findsOneWidget);
      expect(find.text('ABC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('filtered-to-empty explains itself and offers a way back', (
    tester,
  ) async {
    // The shell only builds this grid once the unfiltered library is
    // non-empty, so zero channels means the filters excluded everything.
    // It used to render a blank panel under the sort row.
    var cleared = 0;
    await pumpApp(
      tester,
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(
              channels: const [],
              metadataByChannelId: const {},
              onClearFilters: () => cleared++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No channels match your filters'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(cleared, 1);
  });

  testWidgets('filtered-to-empty omits the action when it cannot clear', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(channels: [], metadataByChannelId: {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No channels match your filters'), findsOneWidget);
    expect(find.text('Clear filters'), findsNothing);
  });

  testWidgets('tapping a tile invokes onChannelSelected', (tester) async {
    IPTVChannel? tapped;
    await pumpApp(
      tester,
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

  testWidgets(
    'tapping the sort trigger then a column in the sheet invokes onSort',
    (tester) async {
      ChannelSortColumn? sorted;
      await pumpApp(
        tester,
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

      await tester.tap(find.text('Sort: Name'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('channel-sort-category')));
      await tester.pumpAndSettle();

      expect(sorted, ChannelSortColumn.category);
      // The sheet closes after picking a column.
      expect(find.byKey(const ValueKey('channel-sort-category')), findsNothing);
    },
  );

  testWidgets(
    'the sort sheet lists every ChannelSortColumn, including Type — the '
    'old fixed four-chip row never exposed it at all',
    (tester) async {
      await pumpApp(
        tester,
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ChannelLibraryGrid(
                channels: channels,
                metadataByChannelId: const {},
                onSort: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sort: Name'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('channel-sort-type')), findsOneWidget);
      expect(find.text('Type'), findsOneWidget);
    },
  );

  testWidgets('per-tile plus button is gone', (tester) async {
    // Multiview toggling used to also live behind an always-visible
    // per-tile icon button in the corner of the tile; that affordance is
    // gone now — the long-press actions sheet (tested below) is the only
    // way to reach it.
    await pumpApp(
      tester,
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(
              channels: channels,
              metadataByChannelId: const {},
              multiviewChannelIds: const {'two'},
              onMultiviewToggle: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.add_to_queue), findsNothing);
    expect(find.byIcon(Icons.remove_from_queue), findsNothing);
    expect(find.byTooltip('Add to multiview'), findsNothing);
    expect(find.byTooltip('Remove from multiview'), findsNothing);
  });

  testWidgets(
    'long-pressing a tile opens an actions menu with Play, split view, and '
    'favorite entries reflecting current state',
    (tester) async {
      IPTVChannel? played;
      IPTVChannel? multiviewToggled;
      IPTVChannel? favoriteToggled;
      await pumpApp(
        tester,
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ChannelLibraryGrid(
                channels: channels,
                metadataByChannelId: const {},
                onChannelSelected: (channel) => played = channel,
                multiviewChannelIds: const {'one'},
                onMultiviewToggle: (channel) => multiviewToggled = channel,
                favoriteChannelIds: const {'two'},
                onFavoriteToggle: (channel) => favoriteToggled = channel,
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.text('One'));
      await tester.pumpAndSettle();

      expect(find.text('Play'), findsOneWidget);
      // 'one' is already in multiview and is not a favorite.
      expect(find.text('Remove from split view'), findsOneWidget);
      expect(find.text('Add to favorites'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('channel-actions-favorite')));
      await tester.pumpAndSettle();

      expect(favoriteToggled?.id, 'one');
      expect(played, isNull);
      expect(multiviewToggled, isNull);
      // The sheet closes after acting on an entry.
      expect(find.text('Play'), findsNothing);
    },
  );

  testWidgets('long-press sheet shows Not for me and toggling it calls '
      'onNotForMeToggle', (tester) async {
    IPTVChannel? notForMeToggled;
    await pumpApp(
      tester,
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(
              channels: channels,
              metadataByChannelId: const {},
              onNotForMeToggle: (channel) => notForMeToggled = channel,
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('One'));
    await tester.pumpAndSettle();

    expect(find.text('Not for me'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('channel-actions-not-for-me')));
    await tester.pumpAndSettle();

    expect(notForMeToggled?.id, 'one');
    // The sheet closes after acting on an entry.
    expect(find.text('Not for me'), findsNothing);
  });

  testWidgets(
    'long-press sheet reflects an already-"not for me" channel and omits '
    'the row when no callback is wired',
    (tester) async {
      await pumpApp(
        tester,
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ChannelLibraryGrid(
                channels: channels,
                metadataByChannelId: const {},
                notForMeChannelIds: const {'one'},
                onNotForMeToggle: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.text('One'));
      await tester.pumpAndSettle();

      expect(find.text('Remove "not for me"'), findsOneWidget);
    },
  );

  testWidgets('long-press actions menu omits entries with no callback wired', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(
              channels: channels,
              metadataByChannelId: {},
            ),
          ),
        ),
      ),
    );

    // No onChannelSelected/onMultiviewToggle/onFavoriteToggle wired at all
    // means there is nothing to show — long-press is a no-op, not a sheet
    // full of dead entries.
    await tester.longPress(find.text('One'));
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
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

    await pumpApp(
      tester,
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
    await pumpApp(
      tester,
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
    await pumpApp(
      tester,
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
    await pumpApp(
      tester,
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

    await pumpApp(
      tester,
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

    await pumpApp(
      tester,
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
    await pumpApp(
      tester,
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

  SliverGrid gridSliver(WidgetTester tester) =>
      tester.widget<SliverGrid>(find.byType(SliverGrid));

  testWidgets('grid gains a column at a representative TV width after the tile '
      'compaction (172px cards fit 10 columns at 1920px, 155px cards fit 11)', (
    tester,
  ) async {
    // The default test surface (800x600) is smaller than the 1920px width
    // this test needs, so the SizedBox below would otherwise be squeezed
    // down to the surface size instead of actually laying out at 1920.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 1080);
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1920,
            height: 900,
            child: ChannelLibraryGrid(
              channels: channels,
              metadataByChannelId: {},
            ),
          ),
        ),
      ),
    );

    final delegate =
        gridSliver(tester).gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 11);
  });

  testWidgets(
    'phone width defaults to a single-column list and hides the toggle '
    'when no callback is supplied',
    (tester) async {
      await pumpApp(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 600,
              child: ChannelLibraryGrid(
                channels: channels,
                metadataByChannelId: {},
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('channel-view-mode-toggle')),
        findsNothing,
      );
      final delegate =
          gridSliver(tester).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 1);
    },
  );

  testWidgets(
    'phone list rows show favorite, live/audio, and quality besides name',
    (tester) async {
      const richChannels = [
        IPTVChannel(
          id: 'news-hd',
          name: 'City News HD',
          streamUrl: 'https://news',
          group: 'News',
          qualityUrls: {'1080p': 'https://news-1080'},
        ),
        IPTVChannel(
          id: 'radio-1',
          name: 'Night Radio',
          streamUrl: 'https://radio',
          group: 'Music',
          isAudioOnly: true,
        ),
      ];

      await pumpApp(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 600,
              child: ChannelLibraryGrid(
                channels: richChannels,
                metadataByChannelId: {},
                favoriteChannelIds: {'news-hd'},
                viewMode: ChannelViewMode.list,
              ),
            ),
          ),
        ),
      );

      expect(find.text('City News HD'), findsOneWidget);
      expect(find.text('Night Radio'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('channel-favorite-news-hd')),
        findsOneWidget,
      );
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('1080p'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'phone list logos decode at tile size and keep extra rows in cache',
    (tester) async {
      const channelsWithArt = [
        IPTVChannel(
          id: 'one',
          name: 'One',
          streamUrl: 'https://one',
          logoUrl: 'https://example.com/logo.png',
        ),
      ];

      await pumpApp(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 600,
              child: ChannelLibraryGrid(
                channels: channelsWithArt,
                metadataByChannelId: {},
                showSortRow: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AiroNetworkImage), findsOneWidget);
      expect(
        tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .scrollCacheExtent,
        const ScrollCacheExtent.pixels(640),
      );
    },
  );

  testWidgets(
    'phone width toggle switches between the single-column list and the '
    'dynamic tile grid',
    (tester) async {
      var mode = ChannelViewMode.list;
      await pumpApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 600,
                child: ChannelLibraryGrid(
                  channels: channels,
                  metadataByChannelId: {},
                  viewMode: mode,
                  onViewModeChanged: (next) => setState(() => mode = next),
                ),
              ),
            ),
          ),
        ),
      );

      // Starts in list mode: single column, and the toggle offers grid next.
      var delegate =
          gridSliver(tester).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 1);
      expect(find.byIcon(Icons.grid_view), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('channel-view-mode-toggle')));
      await tester.pump();

      // Same 360-wide viewport now uses the dynamic multi-column grid, and
      // the toggle icon flips to offer list mode next.
      delegate =
          gridSliver(tester).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, greaterThan(1));
      expect(find.byIcon(Icons.view_list), findsOneWidget);
    },
  );

  testWidgets(
    'phone grid is a compact 3-column tile layout at typical handset widths',
    (tester) async {
      Future<void> pumpAt(double width) {
        return pumpApp(
          tester,
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                height: 800,
                child: const ChannelLibraryGrid(
                  channels: channels,
                  metadataByChannelId: {},
                  viewMode: ChannelViewMode.grid,
                ),
              ),
            ),
          ),
        );
      }

      await pumpAt(360);
      var delegate =
          gridSliver(tester).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
      expect(delegate.mainAxisExtent, lessThan(169));
      expect(tester.takeException(), isNull);

      // Pixel 9 logical width (~411). Same compact 3-up, no overflow.
      await pumpAt(411);
      delegate =
          gridSliver(tester).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
      expect(delegate.mainAxisExtent, lessThan(169));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone grid honors a 2-column and 4-column density', (
    tester,
  ) async {
    Future<void> pumpAt({required double width, required int columns}) {
      return pumpApp(
        tester,
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: 800,
              child: ChannelLibraryGrid(
                channels: channels,
                metadataByChannelId: const {},
                viewMode: ChannelViewMode.grid,
                phoneGridColumns: columns,
              ),
            ),
          ),
        ),
      );
    }

    await pumpAt(width: 411, columns: 2);
    var delegate =
        gridSliver(tester).gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect(delegate.mainAxisExtent, 168);
    expect(tester.takeException(), isNull);

    await pumpAt(width: 411, columns: 4);
    delegate =
        gridSliver(tester).gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 4);
    expect(delegate.mainAxisExtent, 108);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tablet/TV width always uses the dynamic grid regardless of viewMode, '
    'and never shows the toggle',
    (tester) async {
      await pumpApp(
        tester,
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ChannelLibraryGrid(
                channels: channels,
                metadataByChannelId: const {},
                viewMode: ChannelViewMode.list,
                // Even a non-null callback must not surface a toggle here:
                // there's no cramped single column at this width to offer
                // an alternative to.
                onViewModeChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('channel-view-mode-toggle')),
        findsNothing,
      );
      final delegate =
          gridSliver(tester).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, greaterThan(1));
    },
  );

  testWidgets('inserts a browse ad card at index 4', (tester) async {
    const manyChannels = [
      IPTVChannel(id: 'c0', name: 'C0', streamUrl: 'https://c0', group: 'A'),
      IPTVChannel(id: 'c1', name: 'C1', streamUrl: 'https://c1', group: 'A'),
      IPTVChannel(id: 'c2', name: 'C2', streamUrl: 'https://c2', group: 'A'),
      IPTVChannel(id: 'c3', name: 'C3', streamUrl: 'https://c3', group: 'A'),
      IPTVChannel(id: 'c4', name: 'C4', streamUrl: 'https://c4', group: 'A'),
      IPTVChannel(id: 'c5', name: 'C5', streamUrl: 'https://c5', group: 'A'),
    ];

    await pumpApp(
      tester,
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(
              channels: manyChannels,
              metadataByChannelId: {},
              browseAdCard: SizedBox(
                key: ValueKey('test-browse-ad'),
                height: 40,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(ChannelLibraryGrid.browseAdSlotKey), findsOneWidget);
    expect(find.byKey(const ValueKey('test-browse-ad')), findsOneWidget);
    expect(find.byKey(const ValueKey('channel-tile-c0')), findsOneWidget);
    expect(find.byKey(const ValueKey('channel-tile-c5')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'matched tile shows now-playing title; unmatched keeps category (REGRESSION)',
    (tester) async {
      await pumpApp(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ChannelLibraryGrid(
                channels: channels,
                metadataByChannelId: {},
              ),
            ),
          ),
        ),
        nowPlaying: const {'one': 'Evening News'},
      );

      expect(find.text('Evening News'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('News'), findsNothing);
    },
  );

  testWidgets(
    'dense 5-up phone grid drops the subtitle and does not overflow',
    (tester) async {
      await pumpApp(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 411,
              height: 800,
              child: ChannelLibraryGrid(
                channels: channels,
                metadataByChannelId: {},
                viewMode: ChannelViewMode.grid,
                phoneGridColumns: 5,
              ),
            ),
          ),
        ),
        nowPlaying: const {'one': 'Evening News'},
      );

      expect(find.text('Evening News'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TalkBack label includes the now-playing title', (tester) async {
    await pumpApp(
      tester,
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ChannelLibraryGrid(
              channels: channels,
              metadataByChannelId: {},
            ),
          ),
        ),
      ),
      nowPlaying: const {'one': 'Evening News'},
    );

    final label = tester
        .getSemantics(find.byKey(const ValueKey('channel-tile-one')))
        .label;
    expect(label, contains('One'));
    expect(label, contains('Evening News'));
  });

  testWidgets(
    'forwardLoadFailed with a loaded window still shows now-playing titles',
    (tester) async {
      final now = DateTime.utc(2026, 9, 19, 12, 15);
      final window = CompactEpgWindow(
        entries: [
          CompactEpgWindowEntry(
            channelId: 'one',
            channelName: 'One',
            programs: [
              CompactEpgProgram(
                programId: 'p-now',
                title: 'Evening News',
                startsAt: now.subtract(const Duration(minutes: 10)),
                endsAt: now.add(const Duration(minutes: 20)),
              ),
            ],
          ),
        ],
        windowStart: now.subtract(const Duration(minutes: 30)),
        windowEnd: now.add(const Duration(hours: 6)),
        generatedAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        source: CompactEpgSliceSource.localCache,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            guidePagedWindowProvider.overrideWith(
              () => _FakePagedNotifier(
                GuidePagedWindowState(
                  earliestStart: now.subtract(const Duration(minutes: 30)),
                  loadedThrough: now.add(const Duration(hours: 6)),
                  window: window,
                  forwardLoadFailed: true,
                ),
              ),
            ),
            nowTickerProvider.overrideWith((ref) async* {
              yield now;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: ChannelLibraryGrid(
                  channels: channels,
                  metadataByChannelId: {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Evening News'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
    },
  );

  testWidgets(
    'tv peek enabled: focus dwell does not auto-start Watch (CV browse PR2)',
    (tester) async {
      final selected = <String>[];
      await pumpApp(
        tester,
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
        tvPeekEnabled: true,
        previewFactory: _NoOpPeekPreview.new,
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
      // Peek settle is 500ms; stay below that so no decoder starts in this
      // test — we're only proving dwell-to-Watch is disabled.
      await tester.pump(const Duration(milliseconds: 400));
      expect(selected, isEmpty);
      await tester.pump(const Duration(milliseconds: 900));
      expect(selected, isEmpty);
    },
  );
}

/// Avoids starting buffer/live-edge timers in grid peek widget tests.
class _NoOpPeekPreview extends VideoPlayerStreamingService {
  _NoOpPeekPreview() : super(engine: FakeAiroPlaybackEngine(), mixWithOthers: true);

  @override
  Future<void> playChannel(IPTVChannel channel) async {}
}

class _FakePagedNotifier extends GuidePagedWindowNotifier {
  _FakePagedNotifier(this._state);

  final GuidePagedWindowState _state;

  @override
  GuidePagedWindowState build() => _state;
}
