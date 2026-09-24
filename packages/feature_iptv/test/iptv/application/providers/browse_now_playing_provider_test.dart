import 'dart:async';

import 'package:feature_iptv/application/providers/guide_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  final now = DateTime.utc(2026, 9, 19, 12, 15);

  CompactEpgProgram program({
    required String id,
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    return CompactEpgProgram(
      programId: id,
      title: title,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }

  CompactEpgWindow windowFor(List<CompactEpgWindowEntry> entries) {
    return CompactEpgWindow(
      entries: entries,
      windowStart: now.subtract(const Duration(minutes: 30)),
      windowEnd: now.add(const Duration(hours: 6)),
      generatedAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
      source: CompactEpgSliceSource.localCache,
    );
  }

  GuidePagedWindowState pagedState({
    CompactEpgWindow? window,
    bool forwardLoadFailed = false,
    bool isLoadingForward = false,
  }) {
    return GuidePagedWindowState(
      earliestStart: now.subtract(const Duration(minutes: 30)),
      loadedThrough: now.add(const Duration(hours: 6)),
      window: window,
      forwardLoadFailed: forwardLoadFailed,
      isLoadingForward: isLoadingForward,
    );
  }

  ProviderContainer containerFor({
    required GuidePagedWindowState state,
    DateTime? tick,
    Stream<DateTime>? ticks,
  }) {
    assert(tick != null || ticks != null);
    final container = ProviderContainer(
      overrides: [
        guidePagedWindowProvider.overrideWith(() => _FakePagedNotifier(state)),
        nowTickerProvider.overrideWith((ref) async* {
          if (tick != null) {
            yield tick;
            return;
          }
          yield* ticks!;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<Map<String, String>> readTitles(ProviderContainer container) async {
    // A bare `read(nowTickerProvider.future)` never completes: Riverpod
    // pauses the stream with no listener. Keep a watch like a tile would.
    final sub = container.listen(
      browseNowPlayingByChannelIdProvider,
      (_, _) {},
    );
    addTearDown(sub.close);
    await pumpEventQueue();
    return sub.read();
  }

  test('null window yields an empty map', () async {
    final container = containerFor(state: pagedState(), tick: now);

    expect(await readTitles(container), isEmpty);
  });

  test(
    'forwardLoadFailed with a loaded window still maps the airing title',
    () async {
      final window = windowFor([
        CompactEpgWindowEntry(
          channelId: 'channel-1',
          channelName: 'News One',
          programs: [
            program(
              id: 'p-now',
              title: 'Evening News',
              startsAt: now.subtract(const Duration(minutes: 10)),
              endsAt: now.add(const Duration(minutes: 20)),
            ),
          ],
        ),
      ]);
      final container = containerFor(
        state: pagedState(window: window, forwardLoadFailed: true),
        tick: now,
      );

      expect(await readTitles(container), {'channel-1': 'Evening News'});
    },
  );

  test('isLoadingForward with a loaded window still maps titles', () async {
    final window = windowFor([
      CompactEpgWindowEntry(
        channelId: 'channel-1',
        channelName: 'News One',
        programs: [
          program(
            id: 'p-now',
            title: 'Evening News',
            startsAt: now.subtract(const Duration(minutes: 10)),
            endsAt: now.add(const Duration(minutes: 20)),
          ),
        ],
      ),
    ]);
    final container = containerFor(
      state: pagedState(window: window, isLoadingForward: true),
      tick: now,
    );

    expect(await readTitles(container), {'channel-1': 'Evening News'});
  });

  test(
    'remap match: entry.channelId is the playlist id used as the key',
    () async {
      final window = windowFor([
        CompactEpgWindowEntry(
          channelId: 'playlist-channel',
          channelName: 'Remapped',
          programs: [
            program(
              id: 'p-now',
              title: 'World Today',
              startsAt: now.subtract(const Duration(minutes: 5)),
              endsAt: now.add(const Duration(minutes: 25)),
            ),
          ],
        ),
      ]);
      final container = containerFor(
        state: pagedState(window: window),
        tick: now,
      );

      expect(await readTitles(container), {'playlist-channel': 'World Today'});
    },
  );

  test('programs that are not airing are omitted', () async {
    final window = windowFor([
      CompactEpgWindowEntry(
        channelId: 'channel-1',
        channelName: 'News One',
        programs: [
          program(
            id: 'p-later',
            title: 'Tonight',
            startsAt: now.add(const Duration(hours: 1)),
            endsAt: now.add(const Duration(hours: 2)),
          ),
        ],
      ),
    ]);
    final container = containerFor(
      state: pagedState(window: window),
      tick: now,
    );

    expect(await readTitles(container), isEmpty);
  });

  test('blank and whitespace titles are omitted', () async {
    final window = windowFor([
      CompactEpgWindowEntry(
        channelId: 'blank',
        channelName: 'Blank',
        programs: [
          program(
            id: 'p-blank',
            title: '   ',
            startsAt: now.subtract(const Duration(minutes: 1)),
            endsAt: now.add(const Duration(minutes: 1)),
          ),
        ],
      ),
      CompactEpgWindowEntry(
        channelId: 'empty',
        channelName: 'Empty',
        programs: [
          program(
            id: 'p-empty',
            title: '',
            startsAt: now.subtract(const Duration(minutes: 1)),
            endsAt: now.add(const Duration(minutes: 1)),
          ),
        ],
      ),
    ]);
    final container = containerFor(
      state: pagedState(window: window),
      tick: now,
    );

    expect(await readTitles(container), isEmpty);
  });

  test('titles are trimmed', () async {
    final window = windowFor([
      CompactEpgWindowEntry(
        channelId: 'channel-1',
        channelName: 'News One',
        programs: [
          program(
            id: 'p-now',
            title: '  Evening News  ',
            startsAt: now.subtract(const Duration(minutes: 1)),
            endsAt: now.add(const Duration(minutes: 1)),
          ),
        ],
      ),
    ]);
    final container = containerFor(
      state: pagedState(window: window),
      tick: now,
    );

    expect(await readTitles(container), {'channel-1': 'Evening News'});
  });

  test(
    'two overlapping airings keep the first program in list order',
    () async {
      final window = windowFor([
        CompactEpgWindowEntry(
          channelId: 'channel-1',
          channelName: 'News One',
          programs: [
            program(
              id: 'p-first',
              title: 'First Slot',
              startsAt: now.subtract(const Duration(minutes: 10)),
              endsAt: now.add(const Duration(minutes: 20)),
            ),
            program(
              id: 'p-second',
              title: 'Second Slot',
              startsAt: now.subtract(const Duration(minutes: 5)),
              endsAt: now.add(const Duration(minutes: 25)),
            ),
          ],
        ),
      ]);
      final container = containerFor(
        state: pagedState(window: window),
        tick: now,
      );

      expect(await readTitles(container), {'channel-1': 'First Slot'});
    },
  );

  test(
    'sibling without an entry stays absent — first-channel-wins remap',
    () async {
      final window = windowFor([
        CompactEpgWindowEntry(
          channelId: 'channel-1',
          channelName: 'News One',
          programs: [
            program(
              id: 'p-now',
              title: 'Evening News',
              startsAt: now.subtract(const Duration(minutes: 1)),
              endsAt: now.add(const Duration(minutes: 1)),
            ),
          ],
        ),
      ]);
      final container = containerFor(
        state: pagedState(window: window),
        tick: now,
      );

      final map = await readTitles(container);
      expect(map['channel-1'], 'Evening News');
      expect(map.containsKey('channel-2'), isFalse);
    },
  );

  test('ticker tick updates the title when a program ends', () async {
    final ticks = StreamController<DateTime>();
    addTearDown(ticks.close);

    final firstStart = now.subtract(const Duration(minutes: 20));
    final firstEnd = now.add(const Duration(minutes: 5));
    final secondEnd = now.add(const Duration(minutes: 40));
    final window = windowFor([
      CompactEpgWindowEntry(
        channelId: 'channel-1',
        channelName: 'News One',
        programs: [
          program(
            id: 'p-first',
            title: 'Hour One',
            startsAt: firstStart,
            endsAt: firstEnd,
          ),
          program(
            id: 'p-second',
            title: 'Hour Two',
            startsAt: firstEnd,
            endsAt: secondEnd,
          ),
        ],
      ),
    ]);
    final container = containerFor(
      state: pagedState(window: window),
      ticks: ticks.stream,
    );

    final titles = <Map<String, String>>[];
    final sub = container.listen(
      browseNowPlayingByChannelIdProvider,
      (_, next) => titles.add(Map<String, String>.from(next)),
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await pumpEventQueue();

    ticks.add(now);
    await pumpEventQueue();
    ticks.add(firstEnd);
    await pumpEventQueue();

    expect(
      titles.map((m) => m['channel-1']),
      containsAll(['Hour One', 'Hour Two']),
    );
  });
}

class _FakePagedNotifier extends GuidePagedWindowNotifier {
  _FakePagedNotifier(this._state);

  final GuidePagedWindowState _state;

  @override
  GuidePagedWindowState build() => _state;
}
