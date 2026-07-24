import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:platform_epg/platform_epg.dart';

const _runLiveSourceTests = bool.fromEnvironment(
  'AIRO_RUN_LIVE_TV_SOURCE_TESTS',
);

const _playlistUrl = 'https://iptv-org.github.io/iptv/index.m3u';
const _epgWorkerUrl = 'https://worker-9dd4.onrender.com/worker.json';
const _epgChannelsUrl =
    'https://raw.githubusercontent.com/StrangeDrVN/epg/public/output/channels.xml';
const _epgGuideXmlUrl =
    'https://raw.githubusercontent.com/StrangeDrVN/epg/public/output/guide.xml';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'iptv-org live playlist intersects the published EPG guide',
    (WidgetTester tester) async {
      final playlist = await _downloadText(_playlistUrl);
      final channelsXml = await _downloadText(_epgChannelsUrl);
      final guidePath = await _downloadFile(
        _epgGuideXmlUrl,
        'iptv_org_live.xml',
      );
      addTearDown(() async {
        final file = File(guidePath);
        if (await file.exists()) {
          await file.delete();
        }
      });

      final playlistEntries = _parsePlaylistEntries(playlist);
      expect(playlistEntries, isNotEmpty);

      final epgChannelIds = _parseXmltvIds(channelsXml);
      expect(epgChannelIds, isNotEmpty);

      final commonEntries = playlistEntries
          .where((entry) => epgChannelIds.contains(entry.tvgId))
          .take(100)
          .toList(growable: false);
      expect(commonEntries, isNotEmpty);

      final now = DateTime.now().toUtc();
      final repository = await XmltvCompactEpgRepository.fromXmltvFileNative(
        path: guidePath,
        ingestedAt: now,
        channelNamesById: {
          for (final entry in commonEntries) entry.tvgId: entry.name,
        },
      );

      final slice = await repository.loadCurrentNext(
        channelIds: commonEntries.map((entry) => entry.tvgId),
        now: now,
      );
      expect(
        slice.entries.any(
          (entry) => entry.current != null || entry.next != null,
        ),
        isTrue,
      );

      final matchedEntry = commonEntries.firstWhere(
        (playlistEntry) => slice.entryForChannel(playlistEntry.tvgId) != null,
      );
      final epgEntry = slice.entryForChannel(matchedEntry.tvgId)!;

      expect(matchedEntry.streamUrl, isNotEmpty);
      expect(epgEntry.channelName, matchedEntry.name);
      expect(epgEntry.current != null || epgEntry.next != null, isTrue);

      debugPrint(
        'Live source validation matched ${matchedEntry.tvgId} '
        '(${matchedEntry.name}) against the published iptv-org EPG worker.',
      );
    },
    skip: !_runLiveSourceTests,
    tags: <String>{'tv_live_sources'},
  );

  testWidgets(
    'iptv-org live endpoints are reachable',
    (WidgetTester tester) async {
      final workerMetadata = await _downloadText(_epgWorkerUrl);
      expect(workerMetadata, contains('"channels"'));
      expect(workerMetadata, contains('"guide"'));

      final playlist = await _downloadText(_playlistUrl);
      expect(playlist, contains('#EXTM3U'));
    },
    skip: !_runLiveSourceTests,
    tags: <String>{'tv_live_sources'},
  );
}

Future<String> _downloadText(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'GET $url failed with status ${response.statusCode}',
        uri: Uri.parse(url),
      );
    }
    final body = await response.transform(utf8.decoder).join();
    return body;
  } finally {
    client.close(force: true);
  }
}

Future<String> _downloadFile(String url, String fileName) async {
  final text = await _downloadText(url);
  final dir = await Directory.systemTemp.createTemp('airo_tv_live_sources_');
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(text);
  addTearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });
  return file.path;
}

Set<String> _parseXmltvIds(String xml) {
  return RegExp(r'xmltv_id="([^"]+)"')
      .allMatches(xml)
      .map((match) => match.group(1)!)
      .where((id) => id.isNotEmpty)
      .toSet();
}

List<_PlaylistEntry> _parsePlaylistEntries(String m3u) {
  final lines = const LineSplitter().convert(m3u);
  final entries = <_PlaylistEntry>[];
  for (var index = 0; index < lines.length - 1; index++) {
    final line = lines[index];
    if (!line.startsWith('#EXTINF:')) continue;
    final tvgIdMatch = RegExp(r'tvg-id="([^"]*)"').firstMatch(line);
    final nameIndex = line.lastIndexOf(',');
    if (tvgIdMatch == null || nameIndex == -1) continue;

    final tvgId = tvgIdMatch.group(1)!.trim();
    final streamUrl = lines[index + 1].trim();
    final name = line.substring(nameIndex + 1).trim();
    if (tvgId.isEmpty || streamUrl.isEmpty || streamUrl.startsWith('#')) {
      continue;
    }
    entries.add(_PlaylistEntry(tvgId: tvgId, name: name, streamUrl: streamUrl));
  }
  return entries;
}

class _PlaylistEntry {
  const _PlaylistEntry({
    required this.tvgId,
    required this.name,
    required this.streamUrl,
  });

  final String tvgId;
  final String name;
  final String streamUrl;
}
