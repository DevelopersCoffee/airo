import 'package:platform_iptv_org_api/platform_iptv_org_api.dart';
import 'package:test/test.dart';

void main() {
  final fixtures = <IptvOrgEndpoint, Map<String, Object?>>{
    IptvOrgEndpoint.channels: {
      'id': 'News.in',
      'name': 'News',
      'alt_names': ['समाचार'],
      'network': null,
      'owners': ['Example'],
      'country': 'IN',
      'categories': ['news'],
      'is_nsfw': false,
      'launched': null,
      'closed': null,
      'replaced_by': null,
      'website': null,
    },
    IptvOrgEndpoint.feeds: {
      'channel': 'News.in',
      'id': 'DelhiHD',
      'name': 'Delhi HD',
      'alt_names': [],
      'is_main': true,
      'broadcast_area': ['c/IN'],
      'timezones': ['Asia/Kolkata'],
      'languages': ['hin'],
      'format': '1080p',
    },
    IptvOrgEndpoint.logos: {
      'channel': 'News.in',
      'feed': 'DelhiHD',
      'in_use': true,
      'tags': ['horizontal'],
      'width': 1000,
      'height': 500,
      'format': 'SVG',
      'url': 'https://example.com/logo.svg',
    },
    IptvOrgEndpoint.streams: {
      'channel': 'News.in',
      'feed': 'DelhiHD',
      'title': 'News HD',
      'url': 'https://example.com/live.m3u8',
      'referrer': null,
      'user_agent': null,
      'quality': '1080p',
      'label': null,
    },
    IptvOrgEndpoint.guides: {
      'channel': 'News.in',
      'feed': 'DelhiHD',
      'site': 'example.com',
      'site_id': 'news',
      'site_name': 'News',
      'lang': 'hi',
      'sources': [
        {
          'host': 'example.com',
          'url': 'https://example.com/guide.xml',
          'format': 'XML',
        },
      ],
    },
    IptvOrgEndpoint.categories: {
      'id': 'news',
      'name': 'News',
      'description': 'News programming',
    },
    IptvOrgEndpoint.languages: {'name': 'Hindi', 'code': 'hin'},
    IptvOrgEndpoint.countries: {
      'name': 'India',
      'code': 'IN',
      'languages': ['hin', 'eng'],
      'flag': '🇮🇳',
    },
    IptvOrgEndpoint.subdivisions: {
      'country': 'IN',
      'name': 'Delhi',
      'code': 'IN-DL',
      'parent': null,
    },
    IptvOrgEndpoint.cities: {
      'country': 'IN',
      'subdivision': 'IN-DL',
      'name': 'Delhi',
      'code': 'INDEL',
      'wikidata_id': 'Q1353',
    },
    IptvOrgEndpoint.regions: {
      'code': 'ASIA',
      'name': 'Asia',
      'countries': ['IN'],
    },
    IptvOrgEndpoint.timezones: {
      'id': 'Asia/Kolkata',
      'utc_offset': '+05:30',
      'countries': ['IN'],
    },
    IptvOrgEndpoint.blocklist: {
      'channel': 'Blocked.in',
      'reason': 'dmca',
      'ref': 'https://example.com/takedown',
    },
  };

  for (final endpoint in IptvOrgEndpoint.values) {
    test('${endpoint.name} decodes its current schema fixture', () {
      final result = decodeIptvOrgEndpoint(endpoint, [fixtures[endpoint]!]);
      expect(result, isA<List<Object?>>());
      expect((result as List), hasLength(1));
    });

    test('${endpoint.name} rejects a missing required field', () {
      final row = Map<String, Object?>.from(fixtures[endpoint]!);
      final requiredField = switch (endpoint) {
        IptvOrgEndpoint.streams => 'title',
        IptvOrgEndpoint.guides => 'site',
        _ => row.keys.first,
      };
      row.remove(requiredField);

      expect(
        () => decodeIptvOrgEndpoint(endpoint, [row]),
        throwsA(
          isA<IptvOrgSchemaException>()
              .having((error) => error.endpoint, 'endpoint', endpoint)
              .having((error) => error.index, 'index', 0),
        ),
      );
    });
  }

  test('unknown block reasons remain explicit and forward compatible', () {
    final rows =
        decodeIptvOrgEndpoint(IptvOrgEndpoint.blocklist, [
              {
                'channel': 'Example.in',
                'reason': 'court_order',
                'ref': 'https://example.com/order',
              },
            ])
            as List<IptvOrgBlocklistEntry>;

    expect(rows.single.reason, IptvOrgBlockReason.unknown);
    expect(rows.single.rawReason, 'court_order');
  });
}
