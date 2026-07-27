import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  const bbcNews = IPTVChannel(
    id: 'c1',
    name: 'BBC News',
    streamUrl: 'https://example.com/c1.m3u8',
    group: 'News',
  );
  const cnn = IPTVChannel(
    id: 'c2',
    name: 'CNN International',
    streamUrl: 'https://example.com/c2.m3u8',
    group: 'News',
  );

  Future<VideoPlayerStreamingService> pumpPanel(
    WidgetTester tester, {
    List<IPTVChannel> channels = const [bbcNews, cnn],
    String query = '',
    VoidCallback? onChannelSelected,
  }) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final engine = FakeAiroPlaybackEngine(tracks: const []);
    final service = VideoPlayerStreamingService(engine: engine);
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => channels),
          compactEpgRepositoryProvider.overrideWithValue(
            const EmptyCompactEpgRepository(),
          ),
          localIptvSearchQueryProvider.overrideWith((ref) => query),
          iptvStreamingServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: LocalSearchResultsPanel(onChannelSelected: onChannelSelected),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets('empty query shows a prompt, not results', (tester) async {
    await pumpPanel(tester, query: '');

    expect(find.textContaining('Search'), findsWidgets);
    expect(find.text('BBC News'), findsNothing);
  });

  testWidgets('shows matching channel results grouped under a header', (
    tester,
  ) async {
    await pumpPanel(tester, query: 'BBC');

    expect(find.text('Channels'), findsOneWidget);
    expect(find.text('BBC News'), findsOneWidget);
    expect(find.text('CNN International'), findsNothing);
  });

  testWidgets('shows an empty state when nothing matches', (tester) async {
    await pumpPanel(tester, query: 'zzz-no-match');

    expect(find.textContaining('No results'), findsOneWidget);
  });

  testWidgets('result rows are TV-focusable', (tester) async {
    await pumpPanel(tester, query: 'BBC');

    expect(find.byType(TvFocusable), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow at TV viewport size', (tester) async {
    await pumpPanel(tester, query: 'News');

    expect(tester.takeException(), isNull);
  });

  // Regression: selecting a channel used to leave the modal search overlay
  // open with nothing re-claiming D-pad focus, so the remote appeared dead
  // until Back was pressed. onChannelSelected lets the host overlay close
  // itself once playback has started.
  testWidgets(
    'selecting a channel result plays it and calls onChannelSelected',
    (tester) async {
      var selected = false;
      final service = await pumpPanel(
        tester,
        query: 'BBC',
        onChannelSelected: () => selected = true,
      );

      await tester.tap(find.text('BBC News'));
      await tester.pumpAndSettle();

      expect(selected, isTrue);
      expect(service.currentState.currentChannel?.id, 'c1');
      await service.stop();
    },
  );
}
