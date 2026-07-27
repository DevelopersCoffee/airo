import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/tv/iptv_guide_screen.dart';
import 'package:feature_iptv/presentation/widgets/epg_timeline_grid.dart';
import 'package:feature_iptv/presentation/widgets/epg_touch_timeline_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:platform_player/platform_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const newsChannel = IPTVChannel(
    id: 'news-1',
    name: 'City News Live',
    streamUrl: 'https://example.com/news.m3u8',
    group: 'News',
    category: ChannelCategory.news,
  );
  const sportsChannel = IPTVChannel(
    id: 'sports-1',
    name: 'Stadium Sports',
    streamUrl: 'https://example.com/sports.m3u8',
    group: 'Sports',
    category: ChannelCategory.sports,
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<IPTVChannel>? visibleChannels,
    void Function()? onSelectedCallback,
    AiroFormFactor? overrideFormFactor,
    TextScaler textScaler = TextScaler.noScaling,
    CompactEpgProgram? guideProgram,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final channels = visibleChannels ?? [newsChannel, sportsChannel];
    final now = guideProgram == null
        ? DateTime.utc(2026, 7, 17, 12)
        : guideProgram.startsAt.subtract(const Duration(minutes: 30));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => channels),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(
              StreamingState(
                playbackState: PlaybackState.idle,
                isLiveStream: true,
              ),
            ),
          ),
          guidePagedWindowProvider.overrideWith(
            () => _FakePagedNotifier(
              GuidePagedWindowState(
                earliestStart: now,
                loadedThrough: now.add(const Duration(hours: 3)),
                window: CompactEpgWindow(
                  entries: guideProgram == null
                      ? const []
                      : [
                          CompactEpgWindowEntry(
                            channelId: newsChannel.id,
                            channelName: newsChannel.name,
                            programs: [guideProgram],
                          ),
                        ],
                  windowStart: now,
                  windowEnd: now.add(const Duration(hours: 3)),
                  generatedAt: now,
                  expiresAt: now.add(const Duration(hours: 1)),
                  source: CompactEpgSliceSource.unavailable,
                ),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: IptvGuideScreen(
            onChannelSelected: onSelectedCallback ?? () {},
            overrideFormFactor: overrideFormFactor,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'lists all channels with name and group',
    (tester) async {
      await pumpScreen(tester);

      expect(find.text('City News Live'), findsOneWidget);
      expect(find.text('Stadium Sports'), findsOneWidget);
    },
    experimentalLeakTesting: LeakTesting.settings,
  );

  testWidgets(
    'renders the touch timeline grid by default',
    (tester) async {
      await pumpScreen(tester);

      expect(find.byType(EpgTouchTimelineGrid), findsOneWidget);
      expect(find.byType(EpgTimelineGrid), findsNothing);
    },
    experimentalLeakTesting: LeakTesting.settings,
  );

  testWidgets(
    'renders the TV timeline grid when the form factor is TV',
    (tester) async {
      await pumpScreen(tester, overrideFormFactor: AiroFormFactor.tv);

      expect(find.byType(EpgTimelineGrid), findsOneWidget);
      expect(find.byType(EpgTouchTimelineGrid), findsNothing);
    },
    experimentalLeakTesting: LeakTesting.settings,
  );

  testWidgets('TV programme selection opens rich details before playback', (
    tester,
  ) async {
    final start = DateTime.now().toUtc().add(const Duration(hours: 1));
    final program = CompactEpgProgram(
      programId: 'rich-program',
      title: 'The Big Match',
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
      subtitle: 'Semi-final',
      description: 'A decisive evening fixture.',
      categories: const ['Sports', 'Cricket'],
      category: 'Sports',
      episodeNumber: 'S2E5',
      rating: 'PG',
      isNew: true,
    );
    await pumpScreen(
      tester,
      overrideFormFactor: AiroFormFactor.tv,
      guideProgram: program,
    );

    await tester.tap(find.text('The Big Match'));
    await tester.pumpAndSettle();

    expect(find.text('Semi-final'), findsOneWidget);
    expect(find.text('A decisive evening fixture.'), findsOneWidget);
    expect(find.text('Categories: Sports, Cricket'), findsOneWidget);
    expect(find.text('Episode S2E5'), findsOneWidget);
    expect(find.text('Rating: PG'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('Watch now'), findsOneWidget);
    expect(find.text('Set reminder'), findsOneWidget);
    expect(find.text('City News Live'), findsOneWidget);
  });

  testWidgets(
    'shows empty state when there are no channels',
    (tester) async {
      await pumpScreen(tester, visibleChannels: const []);

      expect(find.text('No channels to show yet.'), findsOneWidget);
    },
    experimentalLeakTesting: LeakTesting.settings,
  );

  testWidgets(
    'selecting a channel plays it and calls onChannelSelected',
    (tester) async {
      var selected = false;
      await pumpScreen(tester, onSelectedCallback: () => selected = true);

      await tester.tap(find.text('City News Live'));
      await tester.pump();

      expect(selected, isTrue);
    },
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      notDisposed: {'VideoPlayerController': null},
    ),
  );

  testWidgets(
    'typing in the search box filters the visible channels',
    (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'sports');
      await tester.pump();

      expect(find.text('Stadium Sports'), findsOneWidget);
      expect(find.text('City News Live'), findsNothing);
    },
    experimentalLeakTesting: LeakTesting.settings,
  );

  testWidgets(
    'shows a stale/unavailable banner when the EPG source is unavailable',
    (tester) async {
      await pumpScreen(tester);

      expect(find.textContaining('guide data'), findsOneWidget);
    },
    experimentalLeakTesting: LeakTesting.settings,
  );

  testWidgets('guide search exposes a stable accessible name', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester);

    expect(
      tester.getSemantics(find.byType(TextField)).label,
      contains('Search guide'),
    );
    semantics.dispose();
  });

  testWidgets('guide remains usable at 2x text scale', (tester) async {
    await pumpScreen(tester, textScaler: const TextScaler.linear(2));

    expect(tester.takeException(), isNull);
    expect(
      tester.getSemantics(find.byType(TextField)).label,
      contains('Search guide'),
    );
  });
}

class _FakePagedNotifier extends GuidePagedWindowNotifier {
  _FakePagedNotifier(this._state);

  final GuidePagedWindowState _state;

  @override
  GuidePagedWindowState build() => _state;
}
