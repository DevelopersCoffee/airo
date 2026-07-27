import 'dart:convert';
import 'dart:typed_data';

import 'package:feature_iptv/application/providers/iptv_org_api_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_iptv_org_api/platform_iptv_org_api.dart';

void main() {
  test('taxonomy provider consumes all typed taxonomy endpoints', () async {
    final transport = _TaxonomyTransport();
    final client = IptvOrgApiClient(
      transport: transport,
      cache: MemoryIptvOrgCache(),
      now: () => DateTime.utc(2026, 7, 27),
    );
    final container = ProviderContainer(
      overrides: [iptvOrgApiClientProvider.overrideWith((ref) async => client)],
    );
    addTearDown(container.dispose);

    final taxonomy = await container.read(iptvOrgTaxonomyProvider.future);

    expect(taxonomy.categories.single.id, 'news');
    expect(taxonomy.languages.single.code, 'hin');
    expect(taxonomy.countries.single.code, 'IN');
    expect(taxonomy.subdivisions.single.code, 'IN-DL');
    expect(taxonomy.cities.single.code, 'INDEL');
    expect(taxonomy.regions.single.code, 'ASIA');
    expect(taxonomy.timezones.single.id, 'Asia/Kolkata');
    expect(
      transport.paths,
      unorderedEquals([
        '/api/categories.json',
        '/api/languages.json',
        '/api/countries.json',
        '/api/subdivisions.json',
        '/api/cities.json',
        '/api/regions.json',
        '/api/timezones.json',
      ]),
    );
  });
}

final class _TaxonomyTransport implements IptvOrgTransport {
  final List<String> paths = [];

  static const _rows = <String, Map<String, Object?>>{
    'categories.json': {
      'id': 'news',
      'name': 'News',
      'description': 'News programming',
    },
    'languages.json': {'name': 'Hindi', 'code': 'hin'},
    'countries.json': {
      'name': 'India',
      'code': 'IN',
      'languages': ['hin'],
      'flag': '🇮🇳',
    },
    'subdivisions.json': {
      'country': 'IN',
      'name': 'Delhi',
      'code': 'IN-DL',
      'parent': null,
    },
    'cities.json': {
      'country': 'IN',
      'subdivision': 'IN-DL',
      'name': 'Delhi',
      'code': 'INDEL',
      'wikidata_id': 'Q1353',
    },
    'regions.json': {
      'code': 'ASIA',
      'name': 'Asia',
      'countries': ['IN'],
    },
    'timezones.json': {
      'id': 'Asia/Kolkata',
      'utc_offset': '+05:30',
      'countries': ['IN'],
    },
  };

  @override
  Future<IptvOrgResponse> get(IptvOrgRequest request) async {
    paths.add(request.uri.path);
    final row = _rows[request.uri.pathSegments.last]!;
    return IptvOrgResponse(
      statusCode: 200,
      body: Uint8List.fromList(utf8.encode(jsonEncode([row]))),
    );
  }
}
