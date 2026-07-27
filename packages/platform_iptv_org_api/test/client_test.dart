import 'dart:convert';
import 'dart:typed_data';

import 'package:platform_iptv_org_api/platform_iptv_org_api.dart';
import 'package:test/test.dart';

void main() {
  final channelsBody = Uint8List.fromList(
    utf8.encode(
      jsonEncode([
        {
          'id': 'News.in',
          'name': 'News',
          'alt_names': <String>[],
          'network': null,
          'owners': <String>[],
          'country': 'IN',
          'categories': ['news'],
          'is_nsfw': false,
          'launched': null,
          'closed': null,
          'replaced_by': null,
          'website': null,
        },
      ]),
    ),
  );
  final instant = DateTime.utc(2026, 7, 27, 12);

  test('fresh cache returns without transport', () async {
    final cache = MemoryIptvOrgCache();
    await cache.write(
      'channels',
      IptvOrgCacheEntry(body: channelsBody, fetchedAt: instant),
    );
    final transport = _FakeTransport((_) => throw StateError('not expected'));
    final client = IptvOrgApiClient(
      transport: transport,
      cache: cache,
      now: () => instant.add(const Duration(minutes: 1)),
    );

    expect((await client.fetchChannels()).single.id, 'News.in');
    expect(transport.requests, isEmpty);
  });

  test('stale cache sends validators and 304 refreshes it', () async {
    final cache = MemoryIptvOrgCache();
    await cache.write(
      'channels',
      IptvOrgCacheEntry(
        body: channelsBody,
        fetchedAt: instant,
        etag: '"strong"',
        lastModified: 'Sun, 26 Jul 2026 12:00:00 GMT',
      ),
    );
    final transport = _FakeTransport(
      (_) async => IptvOrgResponse(statusCode: 304, body: Uint8List(0)),
    );
    final now = instant.add(const Duration(days: 2));
    final client = IptvOrgApiClient(
      transport: transport,
      cache: cache,
      now: () => now,
    );

    expect(await client.fetchChannels(), hasLength(1));
    final request = transport.requests.single;
    expect(request.headers['accept-encoding'], 'gzip');
    expect(request.headers['if-none-match'], '"strong"');
    expect(
      request.headers['if-modified-since'],
      'Sun, 26 Jul 2026 12:00:00 GMT',
    );
    expect((await cache.read('channels'))!.fetchedAt, now);
  });

  test('valid 200 replaces cache only after validation', () async {
    final cache = MemoryIptvOrgCache();
    final transport = _FakeTransport(
      (_) async => IptvOrgResponse(
        statusCode: 200,
        body: channelsBody,
        headers: const {
          'etag': '"next"',
          'last-modified': 'Mon, 27 Jul 2026 12:00:00 GMT',
        },
      ),
    );
    final client = IptvOrgApiClient(
      transport: transport,
      cache: cache,
      baseUri: Uri.parse('https://mirror.example/api/'),
      now: () => instant,
    );

    expect(await client.fetchChannels(), hasLength(1));
    expect(
      transport.requests.single.uri.toString(),
      'https://mirror.example/api/channels.json',
    );
    expect((await cache.read('channels'))!.etag, '"next"');
  });

  test('invalid response and offline failure return last-good cache', () async {
    for (final response in [
      IptvOrgResponse(
        statusCode: 200,
        body: Uint8List.fromList(utf8.encode('[{"id": 3}]')),
      ),
      IptvOrgResponse(statusCode: 503, body: Uint8List(0)),
    ]) {
      final cache = MemoryIptvOrgCache();
      await cache.write(
        'channels',
        IptvOrgCacheEntry(body: channelsBody, fetchedAt: instant),
      );
      final client = IptvOrgApiClient(
        transport: _FakeTransport((_) async => response),
        cache: cache,
        cacheTtl: Duration.zero,
        now: () => instant.add(const Duration(days: 1)),
      );

      expect((await client.fetchChannels()).single.id, 'News.in');
      expect((await cache.read('channels'))!.body, channelsBody);
    }
  });

  test('large response decodes successfully across isolate boundary', () async {
    final row = jsonDecode(utf8.decode(channelsBody)) as List<Object?>;
    final largeBody = Uint8List.fromList(
      utf8.encode(jsonEncode(List<Object?>.filled(800, row.single))),
    );
    expect(largeBody.length, greaterThan(50 * 1024));
    final client = IptvOrgApiClient(
      transport: _FakeTransport(
        (_) async => IptvOrgResponse(statusCode: 200, body: largeBody),
      ),
      cache: MemoryIptvOrgCache(),
      now: () => instant,
    );

    expect(await client.fetchChannels(), hasLength(800));
  });
}

final class _FakeTransport implements IptvOrgTransport {
  _FakeTransport(this.handler);

  final Future<IptvOrgResponse> Function(IptvOrgRequest request) handler;
  final List<IptvOrgRequest> requests = [];

  @override
  Future<IptvOrgResponse> get(IptvOrgRequest request) {
    requests.add(request);
    return handler(request);
  }
}
