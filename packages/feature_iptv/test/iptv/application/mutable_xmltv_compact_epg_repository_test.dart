import 'package:feature_iptv/application/mutable_xmltv_compact_epg_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  final start = DateTime.utc(2026, 7, 27, 10);
  final end = start.add(const Duration(hours: 2));
  final query = GuideWindowQuery(
    channelIds: const ['news'],
    windowStart: start,
    windowEnd: end,
    now: start,
  );

  test('user source wins collisions while system fills gaps', () async {
    final repository = MutableXmltvCompactEpgRepository()
      ..updateNamedSource(
        sourceId: 'xmltv-system',
        priority: 1,
        repository: _WindowRepository(
          _window(start, end, [
            _program('system-conflict', 'System', start, 60),
            _program('system-fill', 'System fill', start, 120, offset: 60),
          ]),
        ),
      )
      ..updateNamedSource(
        sourceId: 'xmltv-user',
        priority: 0,
        repository: _WindowRepository(
          _window(start, end, [_program('user', 'User', start, 60)]),
        ),
      );

    final merged = await repository.loadWindow(query);

    expect(merged.entries.single.programs.map((program) => program.programId), [
      'user',
      'system-fill',
    ]);
  });

  test('failed refresh can leave the previous named source intact', () async {
    final repository = MutableXmltvCompactEpgRepository()
      ..updateNamedSource(
        sourceId: 'xmltv-user',
        priority: 0,
        repository: _WindowRepository(
          _window(start, end, [_program('working', 'Working', start, 60)]),
        ),
      );

    final window = await repository.loadWindow(query);

    expect(window.entries.single.programs.single.programId, 'working');
  });
}

CompactEpgWindow _window(
  DateTime start,
  DateTime end,
  List<CompactEpgProgram> programs,
) {
  return CompactEpgWindow(
    entries: [
      CompactEpgWindowEntry(
        channelId: 'news',
        channelName: 'News',
        programs: programs,
      ),
    ],
    windowStart: start,
    windowEnd: end,
    generatedAt: start,
    expiresAt: end,
    source: CompactEpgSliceSource.localCache,
  );
}

CompactEpgProgram _program(
  String id,
  String title,
  DateTime start,
  int durationMinutes, {
  int offset = 0,
}) {
  final startsAt = start.add(Duration(minutes: offset));
  return CompactEpgProgram(
    programId: id,
    title: title,
    startsAt: startsAt,
    endsAt: startsAt.add(Duration(minutes: durationMinutes)),
  );
}

class _WindowRepository implements CompactEpgRepository {
  const _WindowRepository(this.window);

  final CompactEpgWindow window;

  @override
  Future<CompactEpgSlice> loadCurrentNext({
    required Iterable<String> channelIds,
    required DateTime now,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CompactEpgWindow> loadWindow(GuideWindowQuery query) async => window;
}
