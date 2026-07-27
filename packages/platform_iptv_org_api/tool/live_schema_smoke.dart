import 'package:platform_iptv_org_api/platform_iptv_org_api.dart';

Future<void> main() async {
  final snapshot = await IptvOrgApiClient(
    transport: IoIptvOrgTransport(timeout: const Duration(minutes: 2)),
    cache: MemoryIptvOrgCache(),
  ).fetchSnapshot();

  final counts = <String, int>{
    'channels': snapshot.channels.length,
    'feeds': snapshot.feeds.length,
    'logos': snapshot.logos.length,
    'streams': snapshot.streams.length,
    'guides': snapshot.guides.length,
    'categories': snapshot.categories.length,
    'languages': snapshot.languages.length,
    'countries': snapshot.countries.length,
    'subdivisions': snapshot.subdivisions.length,
    'cities': snapshot.cities.length,
    'regions': snapshot.regions.length,
    'timezones': snapshot.timezones.length,
    'blocklist': snapshot.blocklist.length,
  };
  for (final entry in counts.entries) {
    if (entry.value == 0 && entry.key != 'guides') {
      throw StateError('${entry.key} returned no rows');
    }
    print('${entry.key}: ${entry.value}');
  }
}
