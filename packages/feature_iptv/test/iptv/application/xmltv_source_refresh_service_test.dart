import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core_data/core_data.dart';
import 'package:crypto/crypto.dart';
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
    'refresh detects gzip magic and verifies the manifest checksum',
    () async {
      final compressed = Uint8List.fromList(
        gzip.encode(utf8.encode(_minimalXmltv)),
      );
      final gzipDio = Dio()..httpClientAdapter = _BytesXmltvAdapter(compressed);
      final gzipService = XmltvSourceRefreshService(
        dio: gzipDio,
        sourceStore: sourceStore,
        repository: repository,
        downloadDirectoryProvider: () async => tempDir,
      );

      await gzipService.refresh(
        'https://example.com/guide',
        kind: XmltvSourceKind.system,
        expectedSha256: sha256.convert(compressed).toString(),
      );

      final slice = await repository.loadCurrentNext(
        channelIds: const ['chan-1'],
        now: DateTime.utc(2026, 7, 17, 12, 10),
      );
      expect(slice.entryForChannel('chan-1')?.current?.title, 'Test Program');
      final source = (await sourceStore.loadAll()).single;
      expect(source.kind, XmltvSourceKind.system);
      expect(source.lastError, isNull);
      expect(await tempDir.list().toList(), isEmpty);
    },
  );

  test('checksum mismatch records error and keeps previous guide', () async {
    await service.refresh('https://example.com/guide.xml');
    final wrongChecksumDio = Dio()
      ..httpClientAdapter = _FakeXmltvAdapter('<tv/>');
    final wrongChecksumService = XmltvSourceRefreshService(
      dio: wrongChecksumDio,
      sourceStore: sourceStore,
      repository: repository,
      downloadDirectoryProvider: () async => tempDir,
    );

    await expectLater(
      () => wrongChecksumService.refresh(
        'https://example.com/replacement.xml',
        expectedSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
      throwsA(isA<StateError>()),
    );

    final slice = await repository.loadCurrentNext(
      channelIds: const ['chan-1'],
      now: DateTime.utc(2026, 7, 17, 12, 10),
    );
    expect(slice.entryForChannel('chan-1')?.current?.title, 'Test Program');
    final source = await sourceStore.load();
    expect(source?.url, 'https://example.com/guide.xml');
    expect(source?.lastError, contains('checksum'));
  });

  test('manifest resolves and refreshes a same-origin country guide', () async {
    final compressed = Uint8List.fromList(
      gzip.encode(utf8.encode(_minimalXmltv)),
    );
    final manifestDio = Dio()
      ..httpClientAdapter = _ManifestXmltvAdapter(compressed);
    final manifestService = XmltvSourceRefreshService(
      dio: manifestDio,
      sourceStore: sourceStore,
      repository: repository,
      downloadDirectoryProvider: () async => tempDir,
    );

    await manifestService.refreshSystemSourceFromManifest(
      manifestUrl: 'https://data.example/current/manifest.json',
      country: 'in',
    );

    final source = (await sourceStore.loadAll()).single;
    expect(source.url, 'https://data.example/current/guide_IN.xml.gz');
    expect(source.kind, XmltvSourceKind.system);
    expect(source.expectedSha256, sha256.convert(compressed).toString());
  });

  test(
    'refreshSystemGuidesForCountries fetches only the requested guide_XX '
    'shards, never guide_ALL or epg.xml.gz',
    () async {
      final adapter = _MultiCountryManifestAdapter({
        'IN': utf8.encode(
          _minimalXmltv.replaceAll('chan-1', 'MTV.in'),
        ),
        'US': utf8.encode(
          _minimalXmltv.replaceAll('chan-1', 'World.us'),
        ),
        'FR': utf8.encode(_minimalXmltv.replaceAll('chan-1', 'TF1.fr')),
      });
      final manifestDio = Dio()..httpClientAdapter = adapter;
      final manifestService = XmltvSourceRefreshService(
        dio: manifestDio,
        sourceStore: sourceStore,
        repository: repository,
        downloadDirectoryProvider: () async => tempDir,
      );

      await manifestService.refreshSystemGuidesForCountries(
        manifestUrl: 'https://data.example/current/manifest.json',
        countries: {'in', 'us'},
      );

      final now = DateTime.utc(2026, 7, 17, 12, 10);
      final inSlice = await repository.loadCurrentNext(
        channelIds: const ['MTV.in'],
        now: now,
      );
      final usSlice = await repository.loadCurrentNext(
        channelIds: const ['World.us'],
        now: now,
      );
      expect(inSlice.entryForChannel('MTV.in')?.current?.title, 'Test Program');
      expect(usSlice.entryForChannel('World.us')?.current?.title, 'Test Program');

      expect(
        adapter.requestedPaths,
        everyElement(
          anyOf(
            contains('manifest.json'),
            contains('guide_IN.xml.gz'),
            contains('guide_US.xml.gz'),
          ),
        ),
      );
      expect(
        adapter.requestedPaths.any((path) => path.contains('guide_FR')),
        isFalse,
      );
      expect(
        adapter.requestedPaths.any((path) => path.contains('guide_ALL')),
        isFalse,
      );
      expect(
        adapter.requestedPaths.any((path) => path.contains('epg.xml.gz')),
        isFalse,
      );

      final source = (await sourceStore.loadAll()).single;
      expect(source.kind, XmltvSourceKind.system);
    },
  );

  test(
    'refreshSystemGuidesForCountries skips a country missing from the '
    'manifest without failing the others',
    () async {
      final adapter = _MultiCountryManifestAdapter({
        'IN': utf8.encode(_minimalXmltv.replaceAll('chan-1', 'MTV.in')),
      });
      final manifestDio = Dio()..httpClientAdapter = adapter;
      final manifestService = XmltvSourceRefreshService(
        dio: manifestDio,
        sourceStore: sourceStore,
        repository: repository,
        downloadDirectoryProvider: () async => tempDir,
      );

      await manifestService.refreshSystemGuidesForCountries(
        manifestUrl: 'https://data.example/current/manifest.json',
        countries: {'IN', 'ZZ'},
      );

      final now = DateTime.utc(2026, 7, 17, 12, 10);
      final inSlice = await repository.loadCurrentNext(
        channelIds: const ['MTV.in'],
        now: now,
      );
      expect(inSlice.entryForChannel('MTV.in')?.current?.title, 'Test Program');
      expect(
        adapter.requestedPaths.any((path) => path.contains('guide_ZZ')),
        isFalse,
      );
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

  test(
    'refresh with a failing download preserves a previously-working source',
    () async {
      // Establish a working, previously-refreshed source.
      await service.refresh('https://example.com/guide.xml');
      final workingConfig = await sourceStore.load();
      expect(workingConfig?.url, 'https://example.com/guide.xml');
      expect(workingConfig?.lastRefreshedAt, isNotNull);

      // Now attempt to refresh with a different, unreachable URL.
      final failingDio = Dio();
      failingDio.httpClientAdapter = _FailingAdapter();
      final failingService = XmltvSourceRefreshService(
        dio: failingDio,
        sourceStore: sourceStore,
        repository: repository,
        downloadDirectoryProvider: () async => tempDir,
      );

      await expectLater(
        () => failingService.refresh('https://wrong-domain.example/guide.xml'),
        throwsA(anything),
      );

      final config = await sourceStore.load();
      expect(config?.url, 'https://example.com/guide.xml');
      expect(config?.lastRefreshedAt, workingConfig?.lastRefreshedAt);
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

class _BytesXmltvAdapter implements HttpClientAdapter {
  _BytesXmltvAdapter(this._bytes);

  final Uint8List _bytes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(_bytes, 200);
  }

  @override
  void close({bool force = false}) {}
}

class _ManifestXmltvAdapter implements HttpClientAdapter {
  _ManifestXmltvAdapter(this._guideBytes);

  final Uint8List _guideBytes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('manifest.json')) {
      final manifest = jsonEncode({
        'files': {'guide_IN': 'guide_IN.xml.gz'},
        'fileChecksums': {'guide_IN': sha256.convert(_guideBytes).toString()},
      });
      return ResponseBody.fromBytes(
        utf8.encode(manifest),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromBytes(_guideBytes, 200);
  }

  @override
  void close({bool force = false}) {}
}

/// Serves a manifest with one `guide_<CC>` entry per key in [guidesByCountry]
/// (no `guide_ALL`, no `epg.xml.gz`) and each country's gzip bytes, while
/// recording every requested path so tests can assert exactly which shards
/// were fetched.
class _MultiCountryManifestAdapter implements HttpClientAdapter {
  _MultiCountryManifestAdapter(Map<String, List<int>> guidesByCountry)
    : _gzipByCountry = {
        for (final entry in guidesByCountry.entries)
          entry.key: Uint8List.fromList(gzip.encode(entry.value)),
      };

  final Map<String, Uint8List> _gzipByCountry;
  final List<String> requestedPaths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    if (options.path.endsWith('manifest.json')) {
      final manifest = jsonEncode({
        'files': {
          for (final country in _gzipByCountry.keys)
            'guide_$country': 'guide_$country.xml.gz',
        },
        'fileChecksums': {
          for (final country in _gzipByCountry.entries)
            'guide_${country.key}': sha256.convert(country.value).toString(),
        },
      });
      return ResponseBody.fromBytes(
        utf8.encode(manifest),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    for (final entry in _gzipByCountry.entries) {
      if (options.path.endsWith('guide_${entry.key}.xml.gz')) {
        return ResponseBody.fromBytes(entry.value, 200);
      }
    }
    return ResponseBody.fromBytes(const [], 404);
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
