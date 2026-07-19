import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/widgets/epg_timeline_grid.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.com/stream.m3u8',
    group: 'News',
  );

  Future<ProviderContainer> buildContainer(CompactEpgWindow window) async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvChannelsProvider.overrideWith((ref) async => [channel]),
        guideEpgWindowProvider.overrideWith((ref) async => window),
      ],
    );
  }

  testWidgets(
    'renders a row per channel with a program block for each programme',
    (tester) async {
      final now = DateTime.utc(2026, 7, 17, 12);
      final window = CompactEpgWindow(
        entries: [
          CompactEpgWindowEntry(
            channelId: 'channel-1',
            channelName: 'Example Channel',
            programs: [
              CompactEpgProgram(
                programId: 'p1',
                title: 'Morning Show',
                startsAt: now,
                endsAt: now.add(const Duration(hours: 1)),
              ),
            ],
          ),
        ],
        windowStart: now,
        windowEnd: now.add(const Duration(hours: 3)),
        generatedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        source: CompactEpgSliceSource.localCache,
      );
      final container = await buildContainer(window);
      addTearDown(container.dispose);

      IPTVChannel? selected;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(1280, 720),
                navigationMode: NavigationMode.directional,
              ),
              child: Scaffold(
                body: SizedBox(
                  width: 1280,
                  height: 720,
                  child: EpgTimelineGrid(onChannelSelect: (c) => selected = c),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Example Channel'), findsOneWidget);
      expect(find.text('Morning Show'), findsOneWidget);
      // Nothing was tapped/selected in this test — confirms onChannelSelect
      // isn't called spuriously on render.
      expect(selected, isNull);
    },
  );

  testWidgets('shows empty state when there are no channels', (tester) async {
    final now = DateTime.utc(2026, 7, 17, 12);
    final window = CompactEpgWindow(
      entries: const [],
      windowStart: now,
      windowEnd: now.add(const Duration(hours: 3)),
      generatedAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
      source: CompactEpgSliceSource.unavailable,
    );
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvChannelsProvider.overrideWith((ref) async => const []),
        guideEpgWindowProvider.overrideWith((ref) async => window),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(1280, 720),
              navigationMode: NavigationMode.directional,
            ),
            child: Scaffold(
              body: SizedBox(
                width: 1280,
                height: 720,
                child: EpgTimelineGrid(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No channels to show yet.'), findsOneWidget);
  });

  testWidgets(
    'virtualizes channel rows: 500 channels render far fewer row widgets',
    (tester) async {
      final now = DateTime.utc(2026, 7, 17, 12);
      final manyChannels = [
        for (var i = 0; i < 500; i++)
          IPTVChannel(
            id: 'channel-$i',
            name: 'Channel $i',
            streamUrl: 'https://example.com/stream-$i.m3u8',
            group: 'News',
          ),
      ];
      final window = CompactEpgWindow(
        entries: [
          for (var i = 0; i < 500; i++)
            CompactEpgWindowEntry(
              channelId: 'channel-$i',
              channelName: 'Channel $i',
              programs: [
                CompactEpgProgram(
                  programId: 'p-$i',
                  title: 'Show $i',
                  startsAt: now,
                  endsAt: now.add(const Duration(hours: 1)),
                ),
              ],
            ),
        ],
        windowStart: now,
        windowEnd: now.add(const Duration(hours: 3)),
        generatedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        source: CompactEpgSliceSource.localCache,
      );
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => manyChannels),
          guideEpgWindowProvider.overrideWith((ref) async => window),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(1280, 720),
                navigationMode: NavigationMode.directional,
              ),
              child: Scaffold(
                body: SizedBox(
                  width: 1280,
                  height: 720,
                  child: EpgTimelineGrid(onChannelSelect: (_) {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // ValueKey<String>.toString() quotes string values (e.g.
      // "[<'epg_row_channel-0'>]"), so the prefix check must include the
      // leading quote.
      final builtRowCount = find
          .byWidgetPredicate(
            (widget) => widget.key.toString().startsWith("[<'epg_row_"),
          )
          .evaluate()
          .length;

      expect(builtRowCount, greaterThan(0));
      expect(builtRowCount, lessThan(30));
    },
  );

  testWidgets(
    'moving D-pad focus onto a program block does not crash the shared '
    'timeline ScrollController (regression: ScrollController.position '
    'requires exactly one attached position, but header + every visible '
    'row attach simultaneously)',
    (tester) async {
      final now = DateTime.utc(2026, 7, 17, 12);
      const channelTwo = IPTVChannel(
        id: 'channel-2',
        name: 'Second Channel',
        streamUrl: 'https://example.com/stream-2.m3u8',
        group: 'News',
      );
      final window = CompactEpgWindow(
        entries: [
          CompactEpgWindowEntry(
            channelId: 'channel-1',
            channelName: 'Example Channel',
            programs: [
              CompactEpgProgram(
                programId: 'p1',
                title: 'Morning Show',
                startsAt: now,
                endsAt: now.add(const Duration(hours: 1)),
              ),
            ],
          ),
          CompactEpgWindowEntry(
            channelId: 'channel-2',
            channelName: 'Second Channel',
            programs: [
              CompactEpgProgram(
                programId: 'p2',
                title: 'Second Show',
                startsAt: now,
                endsAt: now.add(const Duration(hours: 1)),
              ),
            ],
          ),
        ],
        windowStart: now,
        windowEnd: now.add(const Duration(hours: 3)),
        generatedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        source: CompactEpgSliceSource.localCache,
      );
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith(
            (ref) async => [channel, channelTwo],
          ),
          guideEpgWindowProvider.overrideWith((ref) async => window),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(1280, 720),
                navigationMode: NavigationMode.directional,
              ),
              child: Scaffold(
                body: SizedBox(
                  width: 1280,
                  height: 720,
                  child: EpgTimelineGrid(onChannelSelect: (_) {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Sanity check: both rows (and the header) are built and sharing the
      // single timeline ScrollController simultaneously — the precondition
      // for the crash this test guards against.
      expect(find.text('Example Channel'), findsOneWidget);
      expect(find.text('Second Channel'), findsOneWidget);

      // No widget has focus yet. Sending a D-pad direction moves Flutter's
      // directional focus traversal onto the nearest focusable. Since the
      // channel label (left column) and the row's _ProgramBlock (right
      // column) are BOTH focusable now (the label was made focusable so a
      // channel with no programmes still has a tap/select target), Flutter's
      // findFirstFocusInDirection fallback — which sorts by ascending
      // rect.left for a rightward move — always lands the very first
      // arrowRight on the label, not the program block. A second arrowRight
      // is required to move focus rightward off the label and onto the
      // first program block in that same row.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      // Explicitly verify focus landed on the "Morning Show" program block
      // (not the "Example Channel" label) before proceeding — this is what
      // makes the test actually exercise _ProgramBlock.onFocus ->
      // EpgTimelineGrid._scrollTimelineTo, the crash path this test guards.
      // Focus.of walks up from the "Morning Show" Text's context to the
      // nearest ancestor Focus widget, which is the _ProgramBlock's
      // TvFocusable — so hasFocus is true only if focus actually landed
      // there rather than on the channel label.
      final programBlockContext = tester.element(find.text('Morning Show'));
      expect(
        Focus.of(programBlockContext, createDependency: false).hasFocus,
        isTrue,
        reason:
            'expected the second arrowRight to move focus off the channel '
            'label and onto the "Morning Show" program block',
      );

      // Moving down from the focused program block re-triggers onFocus for
      // the corresponding block in the row below, which is exactly what
      // threw StateError('Bad state: Too many elements') before the fix
      // (ScrollController.position requires exactly one attached
      // ScrollPosition, but header + 2 rows are attached at once).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('time ruler shows the window start in local time, not UTC', (
    tester,
  ) async {
    final windowStart = DateTime.utc(2026, 7, 17, 11);
    final window = CompactEpgWindow(
      entries: const [],
      windowStart: windowStart,
      windowEnd: windowStart.add(const Duration(hours: 3)),
      generatedAt: windowStart,
      expiresAt: windowStart.add(const Duration(hours: 1)),
      source: CompactEpgSliceSource.localCache,
    );
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvChannelsProvider.overrideWith((ref) async => [channel]),
        guideEpgWindowProvider.overrideWith((ref) async => window),
        guideWindowStartProvider.overrideWithValue(windowStart),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(1280, 720),
              navigationMode: NavigationMode.directional,
            ),
            child: Scaffold(
              body: SizedBox(
                width: 1280,
                height: 720,
                child: EpgTimelineGrid(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(EpgTimelineGrid));
    final localLabel = TimeOfDay.fromDateTime(
      windowStart.toLocal(),
    ).format(context);
    expect(find.text(localLabel), findsOneWidget);

    // Guard against regressing to raw-UTC labels on machines where local
    // time differs from UTC (no-op on UTC CI runners).
    final utcLabel = TimeOfDay.fromDateTime(windowStart).format(context);
    if (utcLabel != localLabel) {
      expect(find.text(utcLabel), findsNothing);
    }
  });
}
