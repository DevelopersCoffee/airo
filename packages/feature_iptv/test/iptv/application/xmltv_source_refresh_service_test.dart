import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core_data/core_data.dart';
import 'package:dio/dio.dart';
import 'package:feature_iptv/application/mutable_xmltv_compact_epg_repository.dart';
import 'package:feature_iptv/application/xmltv_source_refresh_service.dart';
import 'package:feature_iptv/application/xmltv_source_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _minimalXmltv = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="chan-1"><display-name>Channel 1</display-name></channel>
  <programme start="20260717120000 +0000" stop="20260717123000 +0000" channel="chan-1">
    <title>Test Program</title>
  </programme>
</tv>
''';

void main() {
  late Directory tempDir;
  late XmltvSourceStore sourceStore;
  late MutableXmltvCompactEpgRepository repository;
  late XmltvSourceRefreshService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    sourceStore = XmltvSourceStore(PreferencesStore(prefs));
    repository = MutableXmltvCompactEpgRepository();
    tempDir = await Directory.systemTemp.createTemp('xmltv_refresh_test');

    final dio = Dio();
    dio.httpClientAdapter = _FakeXmltvAdapter(_minimalXmltv);

    service = XmltvSourceRefreshService(
      dio: dio,
      sourceStore: sourceStore,
      repository: repository,
      downloadDirectoryProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'refresh downloads, parses, updates the repository, and records success',
    () async {
      await service.refresh('https://example.com/guide.xml');

      final now = DateTime.utc(2026, 7, 17, 12, 10);
      final slice = await repository.loadCurrentNext(
        channelIds: ['chan-1'],
        now: now,
      );
      expect(slice.entryForChannel('chan-1')?.current?.title, 'Test Program');

      final config = await sourceStore.load();
      expect(config?.url, 'https://example.com/guide.xml');
      expect(config?.lastRefreshedAt, isNotNull);
      expect(config?.lastError, isNull);
    },
  );

  test(
    'refresh with an invalid URL records an error, does not touch the repository',
    () async {
      await expectLater(
        () => service.refresh('not-a-url'),
        throwsA(isA<ArgumentError>()),
      );

      final config = await sourceStore.load();
      expect(config?.lastError, isNotNull);

      final now = DateTime.utc(2026, 7, 17, 12);
      final slice = await repository.loadCurrentNext(
        channelIds: ['chan-1'],
        now: now,
      );
      expect(slice.availabilityAt(now), CompactEpgAvailability.unavailable);
    },
  );

  test(
    'refreshConfiguredSource is a no-op when nothing is configured',
    () async {
      await service.refreshConfiguredSource();

      final now = DateTime.utc(2026, 7, 17, 12);
      final slice = await repository.loadCurrentNext(
        channelIds: ['chan-1'],
        now: now,
      );
      expect(slice.availabilityAt(now), CompactEpgAvailability.unavailable);
    },
  );

  test('refreshConfiguredSource refreshes the already-saved source', () async {
    await sourceStore.save(
      const XmltvSourceConfig(url: 'https://example.com/guide.xml'),
    );

    await service.refreshConfiguredSource();

    final now = DateTime.utc(2026, 7, 17, 12, 10);
    final slice = await repository.loadCurrentNext(
      channelIds: ['chan-1'],
      now: now,
    );
    expect(slice.entryForChannel('chan-1')?.current?.title, 'Test Program');
  });

  test('refresh deletes the temp download file on success', () async {
    await service.refresh('https://example.com/guide.xml');

    final leftoverFiles = await tempDir.list().toList();
    expect(leftoverFiles, isEmpty);
  });

  test(
    'refresh deletes the temp download file when the download fails',
    () async {
      final failingDio = Dio();
      failingDio.httpClientAdapter = _FailingAdapter();
      final failingService = XmltvSourceRefreshService(
        dio: failingDio,
        sourceStore: sourceStore,
        repository: repository,
        downloadDirectoryProvider: () async => tempDir,
      );

      await expectLater(
        () => failingService.refresh('https://example.com/guide.xml'),
        throwsA(anything),
      );

      final leftoverFiles = await tempDir.list().toList();
      expect(leftoverFiles, isEmpty);

      final config = await sourceStore.load();
      expect(config?.lastError, isNotNull);
    },
  );
}

class _FakeXmltvAdapter implements HttpClientAdapter {
  _FakeXmltvAdapter(this._content);
  final String _content;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = utf8.encode(_content);
    return ResponseBody.fromBytes(bytes, 200);
  }

  @override
  void close({bool force = false}) {}
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      error: 'simulated network failure',
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}
