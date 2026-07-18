import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  group('XmltvCompactEpgRepository', () {
    final ingestedAt = DateTime.utc(2026, 7, 15, 8);

    test('loads current and next programs from XMLTV summaries', () async {
      final repository = XmltvCompactEpgRepository.fromXmltv(
        content: '''
<tv>
  <programme channel="news.one" start="20260715090000 +0000" stop="20260715100000 +0000">
    <title>Morning News</title>
  </programme>
  <programme channel="news.one" start="20260715100000 +0000" stop="20260715103000 +0000">
    <title>Market Watch</title>
  </programme>
  <programme channel="sports.one" start="20260715093000 +0000" stop="20260715103000 +0000">
    <title>Live Match</title>
  </programme>
</tv>
''',
        ingestedAt: ingestedAt,
        channelNamesById: const {'news.one': 'News One'},
        channelNumbersById: const {'news.one': '101'},
      );

      final slice = await repository.loadCurrentNext(
        channelIds: const ['sports.one', 'news.one'],
        now: DateTime.utc(2026, 7, 15, 9, 30),
      );

      expect(slice.source, CompactEpgSliceSource.localCache);
      expect(slice.entries.map((entry) => entry.channelId), [
        'sports.one',
        'news.one',
      ]);
      expect(slice.entryForChannel('sports.one')?.current?.title, 'Live Match');
      final news = slice.entryForChannel('news.one')!;
      expect(news.channelName, 'News One');
      expect(news.channelNumber, '101');
      expect(news.current?.title, 'Morning News');
      expect(news.next?.title, 'Market Watch');
      expect(repository.stats.nativeProgrammeCount, 3);
      expect(repository.stats.retainedProgrammeCount, 3);
      expect(repository.stats.invalidTimestampCount, 0);
    });

    test('normalizes XMLTV timezone offsets to UTC', () async {
      final repository = XmltvCompactEpgRepository.fromXmltv(
        content: '''
<tv>
  <programme channel="offset.one" start="20260715143000 +0530" stop="20260715150000 +0530">
    <title>Offset Programme</title>
  </programme>
</tv>
''',
        ingestedAt: ingestedAt,
      );

      final slice = await repository.loadCurrentNext(
        channelIds: const ['offset.one'],
        now: DateTime.utc(2026, 7, 15, 9, 15),
      );

      expect(
        slice.entryForChannel('offset.one')?.current?.title,
        'Offset Programme',
      );
      expect(
        slice.entryForChannel('offset.one')?.current?.startsAt,
        DateTime.utc(2026, 7, 15, 9),
      );
    });

    test('uses default duration when XMLTV stop is missing', () async {
      final repository = XmltvCompactEpgRepository.fromXmltv(
        content: '''
<tv>
  <programme channel="fallback.one" start="20260715090000 +0000">
    <title>Fallback Stop</title>
  </programme>
</tv>
''',
        ingestedAt: ingestedAt,
        defaultProgrammeDuration: const Duration(minutes: 45),
      );

      final slice = await repository.loadCurrentNext(
        channelIds: const ['fallback.one'],
        now: DateTime.utc(2026, 7, 15, 9, 30),
      );

      final program = slice.entryForChannel('fallback.one')?.current;
      expect(program?.title, 'Fallback Stop');
      expect(program?.endsAt, DateTime.utc(2026, 7, 15, 9, 45));
    });

    test(
      'counts invalid timestamps and returns unavailable empty slices',
      () async {
        final repository = XmltvCompactEpgRepository.fromXmltv(
          content: '''
<tv>
  <programme channel="bad.one" start="not-a-time" stop="20260715100000 +0000">
    <title>Bad Start</title>
  </programme>
  <programme channel="bad.two" start="20260715090000 +0000" stop="20260715080000 +0000">
    <title>Backwards</title>
  </programme>
</tv>
''',
          ingestedAt: ingestedAt,
        );

        final slice = await repository.loadCurrentNext(
          channelIds: const ['bad.one', 'bad.two'],
          now: DateTime.utc(2026, 7, 15, 9, 30),
        );

        expect(slice.entries, isEmpty);
        expect(slice.source, CompactEpgSliceSource.unavailable);
        expect(repository.stats.nativeProgrammeCount, 2);
        expect(repository.stats.retainedProgrammeCount, 0);
        expect(repository.stats.invalidTimestampCount, 2);
      },
    );

    test('preserves native parser truncation stats', () {
      final repository = XmltvCompactEpgRepository.fromXmltv(
        content: '''
<tv>
  <programme channel="one" start="20260715090000 +0000"><title>One</title></programme>
  <programme channel="two" start="20260715100000 +0000"><title>Two</title></programme>
</tv>
''',
        ingestedAt: ingestedAt,
        maxProgrammes: 1,
      );

      expect(repository.stats.nativeProgrammeCount, 2);
      expect(repository.stats.nativeTruncated, isTrue);
      expect(repository.stats.retainedProgrammeCount, 1);
    });

    test('loads current and next programs from an XMLTV file path', () async {
      final directory = await Directory.systemTemp.createTemp(
        'platform-epg-xmltv-file-test-',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final file = File('${directory.path}/guide.xml');
      await file.writeAsString('''
<tv>
  <programme channel="file.news" start="20260715090000 +0000" stop="20260715100000 +0000">
    <title>File Morning News</title>
  </programme>
  <programme channel="file.news" start="20260715100000 +0000" stop="20260715103000 +0000">
    <title>File Market Watch</title>
  </programme>
</tv>
''');

      final repository = XmltvCompactEpgRepository.fromXmltvFile(
        path: file.path,
        ingestedAt: ingestedAt,
        channelNamesById: const {'file.news': 'File News'},
      );

      final slice = await repository.loadCurrentNext(
        channelIds: const ['file.news'],
        now: DateTime.utc(2026, 7, 15, 9, 30),
      );

      final entry = slice.entryForChannel('file.news')!;
      expect(entry.channelName, 'File News');
      expect(entry.current?.title, 'File Morning News');
      expect(entry.next?.title, 'File Market Watch');
      expect(repository.stats.nativeProgrammeCount, 2);
      expect(repository.stats.retainedProgrammeCount, 2);
    });

    test(
      'loads current programs from native-preferred XMLTV file path',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'platform-epg-xmltv-native-file-test-',
        );
        addTearDown(() async {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });
        final file = File('${directory.path}/guide.xml');
        await file.writeAsString('''
<tv>
  <programme channel="native.news" start="20260715090000 +0000" stop="20260715100000 +0000">
    <title>Native File Morning News</title>
  </programme>
</tv>
''');

        final repository = await XmltvCompactEpgRepository.fromXmltvFileNative(
          path: file.path,
          ingestedAt: ingestedAt,
          channelNamesById: const {'native.news': 'Native File News'},
        );

        final slice = await repository.loadCurrentNext(
          channelIds: const ['native.news'],
          now: DateTime.utc(2026, 7, 15, 9, 30),
        );

        final entry = slice.entryForChannel('native.news')!;
        expect(entry.channelName, 'Native File News');
        expect(entry.current?.title, 'Native File Morning News');
        expect(repository.stats.nativeProgrammeCount, 1);
        expect(repository.stats.retainedProgrammeCount, 1);
      },
    );

    test(
      'loads requested current next programs from native-preferred XMLTV file',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'platform-epg-xmltv-current-next-file-test-',
        );
        addTearDown(() async {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });
        final file = File('${directory.path}/guide.xml');
        await file.writeAsString('''
<tv>
  <programme channel="requested.news" start="20260715090000 +0000" stop="20260715100000 +0000">
    <title>Requested Morning News</title>
  </programme>
  <programme channel="requested.news" start="20260715100000 +0000" stop="20260715103000 +0000">
    <title>Requested Market Watch</title>
  </programme>
  <programme channel="ignored.news" start="20260715090000 +0000" stop="20260715100000 +0000">
    <title>Ignored Morning News</title>
  </programme>
</tv>
''');

        final repository =
            await XmltvCompactEpgRepository.fromXmltvCurrentNextFileNative(
              path: file.path,
              ingestedAt: ingestedAt,
              channelIds: const ['requested.news'],
              now: DateTime.utc(2026, 7, 15, 9, 30),
              channelNamesById: const {'requested.news': 'Requested News'},
            );

        final slice = await repository.loadCurrentNext(
          channelIds: const ['requested.news', 'ignored.news'],
          now: DateTime.utc(2026, 7, 15, 9, 30),
        );

        final entry = slice.entryForChannel('requested.news')!;
        expect(entry.channelName, 'Requested News');
        expect(entry.current?.title, 'Requested Morning News');
        expect(entry.next?.title, 'Requested Market Watch');
        expect(slice.entryForChannel('ignored.news'), isNull);
        expect(repository.stats.nativeProgrammeCount, 3);
        expect(repository.stats.retainedProgrammeCount, 2);
        expect(repository.stats.nativeMatchedProgrammeCount, 2);
        expect(repository.stats.nativeRequestedChannelCount, 1);
      },
    );

    test('loadWindow returns only programmes intersecting the window, per '
        'channel, in start order', () async {
      final repository = XmltvCompactEpgRepository.fromXmltv(
        content: '''
<tv>
  <programme channel="sports.one" start="20260715083000 +0000" stop="20260715090000 +0000">
    <title>Before Window</title>
  </programme>
  <programme channel="sports.one" start="20260715090000 +0000" stop="20260715093000 +0000">
    <title>Overlaps Start</title>
  </programme>
  <programme channel="sports.one" start="20260715100000 +0000" stop="20260715103000 +0000">
    <title>Fully Inside</title>
  </programme>
  <programme channel="sports.one" start="20260715110000 +0000" stop="20260715120000 +0000">
    <title>Overlaps End</title>
  </programme>
  <programme channel="sports.one" start="20260715120000 +0000" stop="20260715123000 +0000">
    <title>After Window</title>
  </programme>
  <programme channel="news.one" start="20260715093000 +0000" stop="20260715100000 +0000">
    <title>News Block</title>
  </programme>
</tv>
''',
        ingestedAt: ingestedAt,
        channelNamesById: const {'news.one': 'News One'},
      );

      final window = await repository.loadWindow(
        GuideWindowQuery(
          channelIds: const ['sports.one', 'news.one'],
          windowStart: DateTime.utc(2026, 7, 15, 9),
          windowEnd: DateTime.utc(2026, 7, 15, 11, 30),
          now: DateTime.utc(2026, 7, 15, 10, 15),
        ),
      );

      expect(window.source, CompactEpgSliceSource.localCache);
      expect(window.windowStart, DateTime.utc(2026, 7, 15, 9));
      expect(window.windowEnd, DateTime.utc(2026, 7, 15, 11, 30));
      expect(window.entries.map((e) => e.channelId), [
        'sports.one',
        'news.one',
      ]);

      final sports = window.entryForChannel('sports.one')!;
      expect(sports.programs.map((p) => p.title), [
        'Overlaps Start',
        'Fully Inside',
        'Overlaps End',
      ]);

      final news = window.entryForChannel('news.one')!;
      expect(news.channelName, 'News One');
      expect(news.programs.single.title, 'News Block');
    });

    test('loadWindow omits channels with no programmes in range', () async {
      final repository = XmltvCompactEpgRepository.fromXmltv(
        content: '''
<tv>
  <programme channel="empty.one" start="20260715000000 +0000" stop="20260715010000 +0000">
    <title>Long Gone</title>
  </programme>
</tv>
''',
        ingestedAt: ingestedAt,
      );

      final window = await repository.loadWindow(
        GuideWindowQuery(
          channelIds: const ['empty.one', 'missing.one'],
          windowStart: DateTime.utc(2026, 7, 15, 9),
          windowEnd: DateTime.utc(2026, 7, 15, 10),
          now: DateTime.utc(2026, 7, 15, 9, 30),
        ),
      );

      expect(window.entries, isEmpty);
      expect(window.source, CompactEpgSliceSource.unavailable);
    });

    test('GuideWindowQuery rejects a non-positive time range', () {
      expect(
        () => GuideWindowQuery(
          channelIds: const ['x'],
          windowStart: DateTime.utc(2026, 7, 15, 10),
          windowEnd: DateTime.utc(2026, 7, 15, 9),
          now: DateTime.utc(2026, 7, 15, 9, 30),
        ),
        throwsArgumentError,
      );
    });

    test(
      'parses valid XMLTV timestamps with offsets and rejects invalid values',
      () {
        expect(
          parseXmltvTimestamp('20260715143000 +0530'),
          DateTime.utc(2026, 7, 15, 9),
        );
        expect(
          parseXmltvTimestamp('20260715050000 -0400'),
          DateTime.utc(2026, 7, 15, 9),
        );
        expect(
          parseXmltvTimestamp('20260715090000'),
          DateTime.utc(2026, 7, 15, 9),
        );
        expect(parseXmltvTimestamp('20261315090000 +0000'), isNull);
        expect(parseXmltvTimestamp('20260230090000 +0000'), isNull);
        expect(parseXmltvTimestamp('20260715250000 +0000'), isNull);
        expect(parseXmltvTimestamp('not-a-time'), isNull);
      },
    );
  });
}
