import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:core_entitlements/core_entitlements.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/application/epg_reminder_scheduler.dart';
import 'package:feature_iptv/application/providers/epg_reminder_providers.dart';
import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/richer_context_providers.dart';
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
    RicherContextProvider? richerContextProvider,
    bool remindersAvailable = false,
  }) async {
    if (richerContextProvider != null) {
      SharedPreferences.setMockInitialValues({
        'richer_context.${richerContextProvider.descriptor.id}.metadata': true,
      });
    }
    final prefs = await SharedPreferences.getInstance();
    final channels = visibleChannels ?? [newsChannel, sportsChannel];
    final now = guideProgram == null
        ? DateTime.utc(2026, 7, 17, 12)
        : guideProgram.startsAt.subtract(const Duration(minutes: 30));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (remindersAvailable)
            epgReminderNotificationGatewayProvider.overrideWithValue(
              const _AvailableReminderGateway(),
            ),
          if (richerContextProvider != null) ...[
            richerContextEntitlementsProvider.overrideWithValue(
              const LaunchPromoEntitlements(),
            ),
            richerContextAdapterProvider.overrideWithValue(
              richerContextProvider,
            ),
          ],
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
    expect(find.text('City News Live'), findsOneWidget);

    // No notification gateway is wired here, which is the permanent state on
    // TV. Offering the button anyway gave users a control that silently did
    // nothing: `scheduleReminder` can only answer `unavailable`.
    expect(find.text('Set reminder'), findsNothing);
  });

  testWidgets('programme details offer a reminder once a gateway exists', (
    tester,
  ) async {
    final start = DateTime.now().toUtc().add(const Duration(hours: 1));
    await pumpScreen(
      tester,
      overrideFormFactor: AiroFormFactor.tv,
      remindersAvailable: true,
      guideProgram: CompactEpgProgram(
        programId: 'rich-program',
        title: 'The Big Match',
        startsAt: start,
        endsAt: start.add(const Duration(hours: 1)),
      ),
    );

    await tester.tap(find.text('The Big Match'));
    await tester.pumpAndSettle();

    expect(find.text('Set reminder'), findsOneWidget);
  });

  testWidgets('programme enrichment is lazy and appears in details', (
    tester,
  ) async {
    final provider = _RecordingRicherContextProvider();
    final start = DateTime.now().toUtc().add(const Duration(hours: 1));
    final program = CompactEpgProgram(
      programId: 'enriched-program',
      title: 'The Big Match',
      startsAt: start,
      endsAt: start.add(const Duration(hours: 1)),
    );
    await pumpScreen(
      tester,
      overrideFormFactor: AiroFormFactor.tv,
      guideProgram: program,
      richerContextProvider: provider,
    );

    expect(provider.programmeCalls, 0);

    await tester.tap(find.text('The Big Match'));
    await tester.pumpAndSettle();

    expect(provider.programmeCalls, 1);
    expect(
      find.textContaining('An approved fixture synopsis.'),
      findsOneWidget,
    );
    expect(find.textContaining('Fixture attribution'), findsOneWidget);
    expect(find.text('Watch now'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'long-pressing a TV channel label opens Match EPG for that channel',
    (tester) async {
      await pumpScreen(tester, overrideFormFactor: AiroFormFactor.tv);

      await tester.longPress(find.text('City News Live'));
      await tester.pumpAndSettle();

      expect(
        find.text('Match "City News Live" to EPG channel'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'long-pressing a phone channel label opens Match EPG for that channel',
    (tester) async {
      await pumpScreen(tester);

      await tester.longPress(find.text('Stadium Sports'));
      await tester.pumpAndSettle();

      expect(
        find.text('Match "Stadium Sports" to EPG channel'),
        findsOneWidget,
      );
    },
  );

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

final class _RecordingRicherContextProvider implements RicherContextProvider {
  _RecordingRicherContextProvider()
    : descriptor = RicherContextProviderDescriptor(
        id: 'fixture',
        name: 'Fixture Provider',
        licenseDecision: ProviderLicenseDecision.approved,
        licenseReviewedAt: DateTime.utc(2026, 7, 28),
        attribution: RicherContextAttribution(
          providerId: 'fixture',
          providerName: 'Fixture Provider',
          notice: 'Fixture attribution',
          url: Uri.https('example.invalid', '/attribution'),
        ),
      );

  @override
  final RicherContextProviderDescriptor descriptor;

  int programmeCalls = 0;

  @override
  Future<ProgrammeEnrichment?> enrichProgramme(
    ProgrammeMetadataRequest request,
  ) async {
    programmeCalls++;
    return ProgrammeEnrichment(
      providerItemId: 'programme-1',
      title: request.title,
      synopsis: 'An approved fixture synopsis.',
      attribution: descriptor.attribution,
    );
  }

  @override
  Future<AttributedSportsDeskRow?> fetchSportsFixtures(
    SportsFixturesRequest request,
  ) async => null;
}

/// Stands in for the platform notification gateway the phone entrypoint
/// wires up, so the reminder button's enabled path stays covered.
class _AvailableReminderGateway implements EpgReminderNotificationGateway {
  const _AvailableReminderGateway();

  @override
  bool get isAvailable => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime at,
    required String payloadChannelId,
  }) async {}

  @override
  Future<void> cancel(int notificationId) async {}
}
