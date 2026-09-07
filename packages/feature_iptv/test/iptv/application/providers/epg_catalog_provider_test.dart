import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:feature_iptv/application/providers/epg_catalog_provider.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a well-formed catalog response', () async {
    final adapter = _CatalogAdapter(
      jsonEncode([
        {
          'countryCode': 'IN',
          'sourceId': 'epgshare01',
          'programmeCount': 5000,
          'channelCount': 120,
          'updatedAt': '2026-09-07T00:00:00Z',
        },
      ]),
      statusCode: 200,
    );
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(Dio()..httpClientAdapter = adapter),
        epgCatalogManifestUrlProvider.overrideWithValue(
          'https://example.com/iptv-data/manifest.json',
        ),
      ],
    );
    addTearDown(container.dispose);

    final catalog = await container.read(epgCatalogProvider.future);

    expect(catalog, hasLength(1));
    expect(catalog.single.countryCode, 'IN');
    expect(catalog.single.sourceId, 'epgshare01');
    expect(catalog.single.programmeCount, 5000);
    expect(catalog.single.channelCount, 120);
    expect(catalog.single.updatedAt, DateTime.utc(2026, 9, 7));
    expect(
      adapter.requestedPath,
      'https://example.com/iptv-data/epg_catalog.json',
    );
  });

  test('degrades to an empty list on a 404', () async {
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(
          Dio()..httpClientAdapter = _CatalogAdapter('not found', statusCode: 404),
        ),
        epgCatalogManifestUrlProvider.overrideWithValue(
          'https://example.com/iptv-data/manifest.json',
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(epgCatalogProvider.future), isEmpty);
  });

  test('degrades to an empty list when no manifest URL is configured', () async {
    final container = ProviderContainer(
      overrides: [epgCatalogManifestUrlProvider.overrideWithValue('')],
    );
    addTearDown(container.dispose);

    expect(await container.read(epgCatalogProvider.future), isEmpty);
  });

  test('degrades to an empty list on malformed JSON response', () async {
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(
          Dio()..httpClientAdapter = _CatalogAdapter('not json', statusCode: 200),
        ),
        epgCatalogManifestUrlProvider.overrideWithValue(
          'https://example.com/iptv-data/manifest.json',
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(epgCatalogProvider.future), isEmpty);
  });

  test('degrades to an empty list on transport failure', () async {
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(
          Dio()..httpClientAdapter = _ThrowingCatalogAdapter(),
        ),
        epgCatalogManifestUrlProvider.overrideWithValue(
          'https://example.com/iptv-data/manifest.json',
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(epgCatalogProvider.future), isEmpty);
  });
}

class _CatalogAdapter implements HttpClientAdapter {
  _CatalogAdapter(this._body, {required this.statusCode});

  final String _body;
  final int statusCode;
  String? requestedPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPath = options.uri.toString();
    return ResponseBody.fromBytes(
      utf8.encode(_body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ThrowingCatalogAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw Exception('Connection failed');
  }

  @override
  void close({bool force = false}) {}
}
