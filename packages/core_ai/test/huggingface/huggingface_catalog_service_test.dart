import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core_ai/core_ai.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  List<int> jsonBytes(Object data) => utf8.encode(jsonEncode(data));

  Dio mockDio(List<int> Function(RequestOptions options) responder) {
    final dio = Dio(BaseOptions(responseType: ResponseType.bytes));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          try {
            handler.resolve(
              Response<List<int>>(
                requestOptions: options,
                data: responder(options),
                statusCode: 200,
              ),
            );
          } on Object catch (error) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: error,
                type: DioExceptionType.badResponse,
              ),
            );
          }
        },
      ),
    );
    return dio;
  }

  group('HuggingFaceCatalogService', () {
    test('maps a litert-community repo to OfflineModelInfo', () async {
      final dio = mockDio((options) {
        final path = options.uri.path;
        if (path == '/api/models') {
          return jsonBytes([
            {
              'id': 'litert-community/Demo-1B',
              'tags': ['litert-lm', 'license:apache-2.0', 'text-generation'],
              'pipeline_tag': 'text-generation',
              'library_name': 'litert-lm',
            },
          ]);
        }
        if (path == '/api/models/litert-community/Demo-1B/tree/main') {
          return jsonBytes([
            {'type': 'file', 'path': 'demo-1b.litertlm', 'size': 123456789},
          ]);
        }
        throw StateError('unexpected ${options.uri}');
      });

      final service = HuggingFaceCatalogService(
        dio: dio,
        cache: HuggingFaceCatalogCache(
          resolveRoot: () => Directory.systemTemp,
          fileName: 'unused-litert.json',
        ),
      );
      final models = await service.fetchOrganizationModels(limit: 1);

      expect(models, hasLength(1));
      final model = models.single;
      expect(model.id, 'hf-Demo-1B');
      expect(model.huggingFaceId, 'litert-community/Demo-1B');
      expect(model.fileSizeBytes, 123456789);
      expect(
        model.downloadUrl,
        'https://huggingface.co/litert-community/Demo-1B/resolve/main/demo-1b.litertlm',
      );
      expect(model.credibility, ModelCredibility.official);
      expect(model.license, 'apache-2.0');
    });

    test('skips repos already in the bundled catalog', () async {
      final bundled = ModelCatalog.bundledModels.firstWhere(
        (m) => m.huggingFaceId != null,
      );
      final dio = mockDio((options) {
        return jsonBytes([
          {'id': bundled.huggingFaceId},
        ]);
      });

      final service = HuggingFaceCatalogService(dio: dio);
      final models = await service.fetchOrganizationModels(
        knownHuggingFaceIds: {bundled.huggingFaceId!},
      );

      expect(models, isEmpty);
    });

    test(
      'fetchGgufModels filters gguf, prefers Q4, maps bartowski credibility',
      () async {
        final dio = mockDio((options) {
          final path = options.uri.path;
          if (path == '/api/models') {
            expect(options.queryParameters['filter'], 'gguf');
            expect(options.queryParameters['sort'], 'downloads');
            return jsonBytes([
              {
                'id': 'bartowski/Tiny-Qwen-GGUF',
                'tags': ['gguf', 'license:apache-2.0', 'qwen'],
                'pipeline_tag': 'text-generation',
                'library_name': 'gguf',
              },
            ]);
          }
          if (path == '/api/models/bartowski/Tiny-Qwen-GGUF/tree/main') {
            return jsonBytes([
              {
                'type': 'file',
                'path': 'Tiny-Qwen-Q8_0.gguf',
                'size': 900000000,
              },
              {
                'type': 'file',
                'path': 'Tiny-Qwen-Q4_K_M.gguf',
                'size': 400000000,
              },
              {'type': 'file', 'path': 'Tiny-Qwen.mmproj.gguf', 'size': 1000},
            ]);
          }
          throw StateError('unexpected ${options.uri}');
        });

        final service = HuggingFaceCatalogService(dio: dio);
        final models = await service.fetchGgufModels(limit: 5);

        expect(models, hasLength(1));
        final model = models.single;
        expect(model.huggingFaceId, 'bartowski/Tiny-Qwen-GGUF');
        expect(model.credibility, ModelCredibility.verified);
        expect(model.quantization, ModelQuantization.q4);
        expect(model.provider, AIProvider.gguf);
        expect(model.tags, contains('gguf'));
        expect(model.downloadUrl, contains('Tiny-Qwen-Q4_K_M.gguf'));
        expect(model.description, contains('Q4'));
        expect(model.description, contains('apache-2.0'));
      },
    );

    test('fetchGgufModels applies author filter query param', () async {
      var sawAuthor = false;
      final dio = mockDio((options) {
        if (options.uri.path == '/api/models') {
          expect(options.queryParameters['author'], 'bartowski');
          expect(options.queryParameters['filter'], 'gguf');
          sawAuthor = true;
          return jsonBytes(const []);
        }
        throw StateError('unexpected ${options.uri}');
      });

      final service = HuggingFaceCatalogService(dio: dio);
      await service.fetchGgufModels(authors: const ['bartowski'], limit: 3);
      expect(sawAuthor, isTrue);
    });

    test('resolveFromRepoUrl parses URL and builds OfflineModelInfo', () async {
      final dio = mockDio((options) {
        final path = options.uri.path;
        if (path == '/api/models/bartowski/Demo-GGUF') {
          return jsonBytes({
            'id': 'bartowski/Demo-GGUF',
            'tags': ['gguf', 'license:mit'],
            'pipeline_tag': 'text-generation',
          });
        }
        if (path == '/api/models/bartowski/Demo-GGUF/tree/main') {
          return jsonBytes([
            {'type': 'file', 'path': 'demo-q5_k_m.gguf', 'size': 555000000},
          ]);
        }
        throw StateError('unexpected ${options.uri}');
      });

      final service = HuggingFaceCatalogService(dio: dio);
      final model = await service.resolveFromRepoUrl(
        'https://huggingface.co/bartowski/Demo-GGUF/tree/main',
      );

      expect(model, isNotNull);
      expect(model!.huggingFaceId, 'bartowski/Demo-GGUF');
      expect(model.quantization, ModelQuantization.q5);
      expect(model.provider, AIProvider.gguf);
    });

    test('parseHuggingFaceRepoId accepts URL and bare id', () {
      expect(
        HuggingFaceCatalogService.parseHuggingFaceRepoId(
          'https://huggingface.co/org/model',
        ),
        'org/model',
      );
      expect(
        HuggingFaceCatalogService.parseHuggingFaceRepoId('org/model'),
        'org/model',
      );
      expect(
        HuggingFaceCatalogService.parseHuggingFaceRepoId('not a repo'),
        isNull,
      );
    });

    test('authorCredibility maps known authors', () {
      expect(
        HuggingFaceCatalogService.authorCredibility('litert-community/x'),
        ModelCredibility.official,
      );
      expect(
        HuggingFaceCatalogService.authorCredibility('bartowski/x'),
        ModelCredibility.verified,
      );
      expect(
        HuggingFaceCatalogService.authorCredibility('TheBloke/x'),
        ModelCredibility.verified,
      );
      expect(
        HuggingFaceCatalogService.authorCredibility('random-user/x'),
        ModelCredibility.community,
      );
    });
  });

  group('HuggingFaceCatalogCache', () {
    test('file cache survives a second instance (restart)', () async {
      final temp = await Directory.systemTemp.createTemp('hf_catalog_cache_');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      final cacheA = HuggingFaceCatalogCache(resolveRoot: () => temp);
      final sample = OfflineModelInfo(
        id: 'hf-cached',
        name: 'Cached',
        family: ModelFamily.other,
        fileSizeBytes: 42,
        downloadUrl: 'https://example.com/model.gguf',
        huggingFaceId: 'org/cached',
        credibility: ModelCredibility.community,
        provider: AIProvider.gguf,
        tags: const ['huggingface', 'gguf'],
      );
      await cacheA.save([sample]);

      final cacheB = HuggingFaceCatalogCache(resolveRoot: () => temp);
      final restored = await cacheB.load();
      expect(restored, hasLength(1));
      expect(restored.single.huggingFaceId, 'org/cached');
      expect(
        await File(
          p.join(temp.path, 'model_catalog', 'hf_catalog_metadata.json'),
        ).exists(),
        isTrue,
      );
      expect(await cacheB.hasCachedEntries(), isTrue);
    });
  });

  group('hydratePublicHuggingFaceModels', () {
    test('registers cache when network fails and skips bundled ids', () async {
      final bundled = ModelCatalog.bundledModels.firstWhere(
        (m) => m.huggingFaceId != null,
      );
      final temp = await Directory.systemTemp.createTemp('hf_hydrate_offline_');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final cache = HuggingFaceCatalogCache(resolveRoot: () => temp);
      await cache.save([
        OfflineModelInfo(
          id: 'hf-bundled-dup',
          name: 'Dup',
          family: ModelFamily.other,
          fileSizeBytes: 1,
          huggingFaceId: bundled.huggingFaceId,
          credibility: ModelCredibility.community,
        ),
        OfflineModelInfo(
          id: 'hf-offline-only',
          name: 'Offline Only',
          family: ModelFamily.qwen,
          fileSizeBytes: 99,
          huggingFaceId: 'bartowski/offline-only',
          credibility: ModelCredibility.verified,
          provider: AIProvider.gguf,
          tags: const ['gguf'],
        ),
      ]);

      final dio = Dio(BaseOptions(responseType: ResponseType.bytes));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: 'offline',
              ),
            );
          },
        ),
      );

      final registry = ModelRegistry();
      registry.registerModels(ModelCatalog.bundledModels);

      final hydration = await hydratePublicHuggingFaceModels(
        registry,
        service: HuggingFaceCatalogService(dio: dio, cache: cache),
        cache: cache,
      );

      expect(
        hydration.availability,
        HuggingFaceCatalogAvailability.offlineCached,
      );
      expect(registry.getModel('hf-offline-only'), isNotNull);
      expect(registry.getModel('hf-bundled-dup'), isNull);
    });

    test('writes merged live feed to cache', () async {
      final temp = await Directory.systemTemp.createTemp('hf_hydrate_online_');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final cache = HuggingFaceCatalogCache(resolveRoot: () => temp);

      final dio = mockDio((options) {
        final path = options.uri.path;
        final filter = options.queryParameters['filter'];
        if (path == '/api/models' && filter == 'gguf') {
          return jsonBytes([
            {
              'id': 'bartowski/Live-GGUF',
              'tags': ['gguf', 'license:apache-2.0'],
            },
          ]);
        }
        if (path == '/api/models') {
          return jsonBytes([
            {
              'id': 'litert-community/Live-LiteRT',
              'tags': ['litert-lm', 'license:apache-2.0'],
            },
          ]);
        }
        if (path.endsWith('/tree/main')) {
          final isGguf = path.contains('Live-GGUF');
          return jsonBytes([
            {
              'type': 'file',
              'path': isGguf ? 'model-Q4_K_M.gguf' : 'model.litertlm',
              'size': isGguf ? 111 : 222,
            },
          ]);
        }
        throw StateError('unexpected ${options.uri}');
      });

      final registry = ModelRegistry();
      final hydration = await hydratePublicHuggingFaceModels(
        registry,
        service: HuggingFaceCatalogService(dio: dio, cache: cache),
        cache: cache,
        organizationLimit: 5,
        ggufLimit: 5,
      );

      expect(hydration.availability, HuggingFaceCatalogAvailability.online);
      final cached = await cache.load();
      expect(cached.length, greaterThanOrEqualTo(2));
      expect(
        cached.any((m) => m.huggingFaceId == 'bartowski/Live-GGUF'),
        isTrue,
      );
      expect(
        cached.any((m) => m.huggingFaceId == 'litert-community/Live-LiteRT'),
        isTrue,
      );
      expect(registry.getModel('hf-Live-GGUF'), isNotNull);
      expect(registry.getModel('hf-Live-LiteRT'), isNotNull);
    });

    test('neverFetched when offline with empty cache', () async {
      final temp = await Directory.systemTemp.createTemp('hf_hydrate_empty_');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final cache = HuggingFaceCatalogCache(resolveRoot: () => temp);
      final dio = Dio(BaseOptions(responseType: ResponseType.bytes));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
          },
        ),
      );

      final hydration = await hydratePublicHuggingFaceModels(
        ModelRegistry(),
        service: HuggingFaceCatalogService(dio: dio, cache: cache),
        cache: cache,
      );
      expect(
        hydration.availability,
        HuggingFaceCatalogAvailability.neverFetched,
      );
      expect(hydration.models, isEmpty);
    });
  });

  group('catalog JSON off-main helpers', () {
    test('decodeCatalogJson handles payloads over 50KB', () async {
      final entries = List.generate(
        1200,
        (i) => {
          'id': 'org/model-$i-with-extra-padding-for-size',
          'tags': ['gguf', 'license:mit', 'text-generation', 'qwen'],
        },
      );
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(entries)));
      expect(bytes.lengthInBytes, greaterThan(50 * 1024));
      final decoded = await decodeCatalogJson(bytes);
      expect(decoded, hasLength(1200));
    });
  });
}
