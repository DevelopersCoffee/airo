import 'package:core_data/core_data.dart';
import 'package:feature_iptv/application/epg_reminder_scheduler.dart';
import 'package:feature_iptv/application/epg_reminder_store.dart';
import 'package:feature_iptv/application/providers/epg_reminder_providers.dart';
import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/widgets/epg_program_progress.dart';
import 'package:feature_iptv/presentation/widgets/epg_touch_timeline_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 7, 20, 12, 10);

  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.com/stream.m3u8',
    group: 'News',
  );

  CompactEpgProgram program(
    String id,
    String title,
    DateTime start,
    DateTime end,
  ) {
    return CompactEpgProgram(
      programId: id,
      title: title,
      startsAt: start,
      endsAt: end,
    );
  }

  GuidePagedWindowState fixedStateWithEntries(
    List<CompactEpgWindowEntry> entries,
  ) {
    final earliest = DateTime.utc(2026, 7, 20, 11, 30);
    final through = DateTime.utc(2026, 7, 20, 18, 30);
    return GuidePagedWindowState(
      earliestStart: earliest,
      loadedThrough: through,
      window: CompactEpgWindow(
        entries: entries,
        windowStart: earliest,
        windowEnd: through,
        generatedAt: fixedNow,
        expiresAt: fixedNow.add(const Duration(hours: 24)),
        source: CompactEpgSliceSource.localCache,
      ),
    );
  }

  GuidePagedWindowState fixedState(List<CompactEpgProgram> programs) {
    return fixedStateWithEntries([
      CompactEpgWindowEntry(
        channelId: 'channel-1',
        channelName: 'Example Channel',
        programs: programs,
      ),
    ]);
  }

  Future<SharedPreferences> resetPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  Future<void> pumpGrid(
    WidgetTester tester, {
    required GuidePagedWindowState state,
    void Function(IPTVChannel)? onChannelSelect,
    void Function(IPTVChannel, CompactEpgProgram)? onReminderToggle,
    List<EpgReminder> reminders = const [],
    EpgReminderNotificationGateway? gateway,
    List<IPTVChannel>? channels,
  }) async {
    final prefs = await resetPrefs();
    final effectiveChannels = channels ?? const [channel];
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => effectiveChannels),
          hiddenGroupIdsProvider.overrideWith((ref) async => const <String>{}),
          guidePagedWindowProvider.overrideWith(
            () => _FakePagedNotifier(state),
          ),
          nowTickerProvider.overrideWith((ref) => Stream.value(fixedNow)),
          epgRemindersProvider.overrideWith((ref) async => reminders),
          if (gateway != null)
            epgReminderNotificationGatewayProvider.overrideWithValue(gateway),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EpgTouchTimelineGrid(
              onChannelSelect: onChannelSelect,
              onReminderToggle: onReminderToggle,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('epgProgramProgress', () {
    test('is 0 at start, 0.5 midway, and clamps to 1 after end', () {
      final start = DateTime.utc(2026, 7, 20, 12);
      final end = DateTime.utc(2026, 7, 20, 13);

      expect(epgProgramProgress(startsAt: start, endsAt: end, now: start), 0);
      expect(
        epgProgramProgress(
          startsAt: start,
          endsAt: end,
          now: DateTime.utc(2026, 7, 20, 12, 30),
        ),
        0.5,
      );
      expect(
        epgProgramProgress(
          startsAt: start,
          endsAt: end,
          now: DateTime.utc(2026, 7, 20, 14),
        ),
        1,
      );
    });

    test('zero-duration program returns 0', () {
      final at = DateTime.utc(2026, 7, 20, 12);
      expect(epgProgramProgress(startsAt: at, endsAt: at, now: at), 0);
    });
  });

  group('epgProgramIsAiring', () {
    test('treats the end instant as no longer airing', () {
      final start = DateTime.utc(2026, 7, 20, 12);
      final end = DateTime.utc(2026, 7, 20, 13);

      expect(
        epgProgramIsAiring(startsAt: start, endsAt: end, now: start),
        isTrue,
      );
      expect(
        epgProgramIsAiring(startsAt: start, endsAt: end, now: end),
        isFalse,
      );
    });
  });

  group('epgProgramMinutesLeft', () {
    test('returns whole minutes and clamps elapsed programs to 0', () {
      expect(
        epgProgramMinutesLeft(
          endsAt: DateTime.utc(2026, 7, 20, 13),
          now: DateTime.utc(2026, 7, 20, 12, 10),
        ),
        50,
      );
      expect(
        epgProgramMinutesLeft(
          endsAt: DateTime.utc(2026, 7, 20, 12),
          now: DateTime.utc(2026, 7, 20, 12, 10),
        ),
        0,
      );
    });
  });

  testWidgets(
    'renders channel label, program blocks, and progress on the airing block',
    (tester) async {
      await pumpGrid(
        tester,
        state: fixedState([
          program(
            'past',
            'Past Show',
            DateTime.utc(2026, 7, 20, 11, 30),
            DateTime.utc(2026, 7, 20, 12),
          ),
          program(
            'now',
            'Now Show',
            DateTime.utc(2026, 7, 20, 12),
            DateTime.utc(2026, 7, 20, 13),
          ),
          program(
            'future',
            'Future Show',
            DateTime.utc(2026, 7, 20, 13),
            DateTime.utc(2026, 7, 20, 14),
          ),
        ]),
      );

      expect(find.text('Example Channel'), findsOneWidget);
      expect(find.text('Now Show'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('min left'), findsOneWidget);
    },
  );

  testWidgets('horizontal drag reveals later programs without losing sync', (
    tester,
  ) async {
    await pumpGrid(
      tester,
      state: fixedState([
        program(
          'late',
          'Late Show',
          DateTime.utc(2026, 7, 20, 17),
          DateTime.utc(2026, 7, 20, 18),
        ),
      ]),
    );
    expect(find.text('Late Show'), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('epg_touch_row_channel-1')),
      const Offset(-2200, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Late Show'), findsOneWidget);
  });

  testWidgets('newly materialized rows inherit the horizontal time offset', (
    tester,
  ) async {
    final channels = [
      channel,
      for (var i = 2; i <= 30; i++)
        IPTVChannel(
          id: 'channel-$i',
          name: 'Channel $i',
          streamUrl: 'https://example.com/stream-$i.m3u8',
          group: 'News',
        ),
    ];
    final targetProgram = program(
      'late-25',
      'Late Show 25',
      DateTime.utc(2026, 7, 20, 17),
      DateTime.utc(2026, 7, 20, 18),
    );

    await pumpGrid(
      tester,
      channels: channels,
      state: fixedStateWithEntries([
        CompactEpgWindowEntry(
          channelId: 'channel-25',
          channelName: 'Channel 25',
          programs: [targetProgram],
        ),
      ]),
    );

    final visibleTouchRow = find.byWidgetPredicate(
      (widget) => widget.key.toString().startsWith("[<'epg_touch_row_"),
    );
    expect(visibleTouchRow, findsWidgets);
    await tester.drag(visibleTouchRow.first, const Offset(-2200, 0));
    await tester.pumpAndSettle();

    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.text('Channel 25'),
      500,
      scrollable: verticalScrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('Channel 25'), findsOneWidget);
    expect(find.text('Late Show 25'), findsOneWidget);
  });

  testWidgets('tapping the airing block selects the channel', (tester) async {
    IPTVChannel? selected;
    await pumpGrid(
      tester,
      state: fixedState([
        program(
          'now',
          'Now Show',
          DateTime.utc(2026, 7, 20, 12),
          DateTime.utc(2026, 7, 20, 13),
        ),
      ]),
      onChannelSelect: (c) => selected = c,
    );

    await tester.tap(find.text('Now Show'));
    await tester.pump();

    expect(selected?.id, 'channel-1');
  });

  testWidgets('tapping a future block toggles a reminder when available', (
    tester,
  ) async {
    CompactEpgProgram? reminded;
    await pumpGrid(
      tester,
      state: fixedState([
        program(
          'future',
          'Future Show',
          DateTime.utc(2026, 7, 20, 12, 20),
          DateTime.utc(2026, 7, 20, 13),
        ),
      ]),
      gateway: _AvailableGateway(),
      onReminderToggle: (c, p) => reminded = p,
    );

    await tester.tap(find.text('Future Show'));
    await tester.pump();

    expect(reminded?.programId, 'future');
  });

  testWidgets('future blocks do not toggle reminders when unavailable', (
    tester,
  ) async {
    var tapped = false;
    await pumpGrid(
      tester,
      state: fixedState([
        program(
          'future',
          'Future Show',
          DateTime.utc(2026, 7, 20, 12, 20),
          DateTime.utc(2026, 7, 20, 13),
        ),
      ]),
      onReminderToggle: (_, _) => tapped = true,
    );

    await tester.tap(find.text('Future Show'), warnIfMissed: false);
    await tester.pump();

    expect(tapped, isFalse);
  });

  testWidgets('past blocks are dimmed and non-interactive', (tester) async {
    var tapped = false;
    await pumpGrid(
      tester,
      state: fixedState([
        program(
          'past',
          'Past Show',
          DateTime.utc(2026, 7, 20, 11, 30),
          DateTime.utc(2026, 7, 20, 12),
        ),
      ]),
      onChannelSelect: (_) => tapped = true,
      onReminderToggle: (_, _) => tapped = true,
    );

    await tester.drag(
      find.byKey(const ValueKey('epg_touch_row_channel-1')),
      const Offset(240, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Past Show'), warnIfMissed: false);
    await tester.pump();

    expect(tapped, isFalse);
  });

  testWidgets('reminded future blocks show a bell indicator', (tester) async {
    final reminder = EpgReminder(
      channelId: 'channel-1',
      channelName: 'Example Channel',
      programId: 'future',
      programTitle: 'Future Show',
      startsAt: DateTime.utc(2026, 7, 20, 12, 20),
      endsAt: DateTime.utc(2026, 7, 20, 13),
      notificationId: 7,
    );
    await pumpGrid(
      tester,
      state: fixedState([
        program(
          'future',
          'Future Show',
          DateTime.utc(2026, 7, 20, 12, 20),
          DateTime.utc(2026, 7, 20, 13),
        ),
      ]),
      reminders: [reminder],
    );

    expect(find.byIcon(Icons.notifications_active), findsOneWidget);
  });

  testWidgets('forward edge scrolling calls extendForward', (tester) async {
    final notifier = _FakePagedNotifier(
      fixedState([
        program(
          'late',
          'Late Show',
          DateTime.utc(2026, 7, 20, 17),
          DateTime.utc(2026, 7, 20, 18),
        ),
      ]),
    );
    final prefs = await resetPrefs();
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => [channel]),
          hiddenGroupIdsProvider.overrideWith((ref) async => const <String>{}),
          guidePagedWindowProvider.overrideWith(() => notifier),
          nowTickerProvider.overrideWith((ref) => Stream.value(fixedNow)),
          epgRemindersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: Scaffold(body: EpgTouchTimelineGrid())),
      ),
    );
    await tester.pump();

    await tester.drag(
      find.byKey(const ValueKey('epg_touch_row_channel-1')),
      const Offset(-2100, 0),
    );
    await tester.pumpAndSettle();

    expect(notifier.extendCalls, greaterThan(0));
  });

  testWidgets(
    'forwardLoadFailed shows an inline retry that calls retryForward',
    (tester) async {
      final failing = _FakePagedNotifier(
        fixedState(const []).copyWith(forwardLoadFailed: true),
      );
      final prefs = await resetPrefs();
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            iptvChannelsProvider.overrideWith((ref) async => [channel]),
            hiddenGroupIdsProvider.overrideWith(
              (ref) async => const <String>{},
            ),
            guidePagedWindowProvider.overrideWith(() => failing),
            nowTickerProvider.overrideWith((ref) => Stream.value(fixedNow)),
            epgRemindersProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(
            home: Scaffold(body: EpgTouchTimelineGrid()),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining("Couldn't load more guide data"),
        findsOneWidget,
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(failing.retryCalls, 1);
    },
  );

  testWidgets('guide open prunes elapsed reminders', (tester) async {
    final prefs = await resetPrefs();
    final store = EpgReminderStore(PreferencesStore(prefs));
    var reminderReadCount = 0;
    await store.save(
      EpgReminder(
        channelId: 'channel-1',
        channelName: 'Example Channel',
        programId: 'elapsed',
        programTitle: 'Elapsed Show',
        startsAt: DateTime.utc(2026, 7, 20, 10),
        endsAt: DateTime.utc(2026, 7, 20, 11),
        notificationId: 9,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => [channel]),
          hiddenGroupIdsProvider.overrideWith((ref) async => const <String>{}),
          guidePagedWindowProvider.overrideWith(
            () => _FakePagedNotifier(fixedState(const [])),
          ),
          nowTickerProvider.overrideWith((ref) => Stream.value(fixedNow)),
          epgReminderNotificationGatewayProvider.overrideWithValue(
            _AvailableGateway(),
          ),
          epgRemindersProvider.overrideWith((ref) {
            reminderReadCount++;
            return store.list();
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: EpgTouchTimelineGrid())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(await store.contains('elapsed'), isFalse);
    expect(reminderReadCount, greaterThan(1));
  });
}

class _FakePagedNotifier extends GuidePagedWindowNotifier {
  _FakePagedNotifier(this._state);

  final GuidePagedWindowState _state;
  var extendCalls = 0;
  var retryCalls = 0;

  @override
  GuidePagedWindowState build() => _state;

  @override
  Future<void> extendForward() async {
    extendCalls++;
  }

  @override
  Future<void> retryForward() async {
    retryCalls++;
  }
}

class _AvailableGateway implements EpgReminderNotificationGateway {
  @override
  bool get isAvailable => true;

  @override
  Future<void> cancel(int notificationId) async {}

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
}
