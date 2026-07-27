import 'dart:convert';
import 'dart:typed_data';

import 'package:core_workers/core_workers.dart';

import 'cache.dart';
import 'models.dart';
import 'transport.dart';

const _offMainDecodeThresholdBytes = 50 * 1024;
final _defaultBaseUri = Uri.parse('https://iptv-org.github.io/api/');

final class IptvOrgApiClient {
  IptvOrgApiClient({
    required this.transport,
    required this.cache,
    Uri? baseUri,
    this.cacheTtl = const Duration(hours: 24),
    DateTime Function()? now,
  }) : baseUri = baseUri ?? _defaultBaseUri,
       _now = now ?? DateTime.now {
    if (!this.baseUri.hasScheme || !this.baseUri.path.endsWith('/')) {
      throw ArgumentError.value(
        this.baseUri,
        'baseUri',
        'must be absolute and end with /',
      );
    }
  }

  final IptvOrgTransport transport;
  final IptvOrgCache cache;
  final Uri baseUri;
  final Duration cacheTtl;
  final DateTime Function() _now;

  Future<List<IptvOrgChannel>> fetchChannels() =>
      _fetch(IptvOrgEndpoint.channels);
  Future<List<IptvOrgFeed>> fetchFeeds() => _fetch(IptvOrgEndpoint.feeds);
  Future<List<IptvOrgLogo>> fetchLogos() => _fetch(IptvOrgEndpoint.logos);
  Future<List<IptvOrgStream>> fetchStreams() => _fetch(IptvOrgEndpoint.streams);
  Future<List<IptvOrgGuide>> fetchGuides() => _fetch(IptvOrgEndpoint.guides);
  Future<List<IptvOrgCategory>> fetchCategories() =>
      _fetch(IptvOrgEndpoint.categories);
  Future<List<IptvOrgLanguage>> fetchLanguages() =>
      _fetch(IptvOrgEndpoint.languages);
  Future<List<IptvOrgCountry>> fetchCountries() =>
      _fetch(IptvOrgEndpoint.countries);
  Future<List<IptvOrgSubdivision>> fetchSubdivisions() =>
      _fetch(IptvOrgEndpoint.subdivisions);
  Future<List<IptvOrgCity>> fetchCities() => _fetch(IptvOrgEndpoint.cities);
  Future<List<IptvOrgRegion>> fetchRegions() => _fetch(IptvOrgEndpoint.regions);
  Future<List<IptvOrgTimezone>> fetchTimezones() =>
      _fetch(IptvOrgEndpoint.timezones);
  Future<List<IptvOrgBlocklistEntry>> fetchBlocklist() =>
      _fetch(IptvOrgEndpoint.blocklist);

  Future<IptvOrgSnapshot> fetchSnapshot() async {
    final channels = fetchChannels();
    final feeds = fetchFeeds();
    final logos = fetchLogos();
    final streams = fetchStreams();
    final guides = fetchGuides();
    final categories = fetchCategories();
    final languages = fetchLanguages();
    final countries = fetchCountries();
    final subdivisions = fetchSubdivisions();
    final cities = fetchCities();
    final regions = fetchRegions();
    final timezones = fetchTimezones();
    final blocklist = fetchBlocklist();

    return IptvOrgSnapshot(
      channels: await channels,
      feeds: await feeds,
      logos: await logos,
      streams: await streams,
      guides: await guides,
      categories: await categories,
      languages: await languages,
      countries: await countries,
      subdivisions: await subdivisions,
      cities: await cities,
      regions: await regions,
      timezones: await timezones,
      blocklist: await blocklist,
    );
  }

  Future<List<T>> _fetch<T>(IptvOrgEndpoint endpoint) async {
    final now = _now().toUtc();
    final cached = await cache.read(endpoint.name);
    if (cached != null && now.difference(cached.fetchedAt) <= cacheTtl) {
      return (await _decode(endpoint, cached.body)).cast<T>();
    }

    final headers = <String, String>{'accept-encoding': 'gzip'};
    if (cached?.etag case final etag?) headers['if-none-match'] = etag;
    if (cached?.lastModified case final modified?) {
      headers['if-modified-since'] = modified;
    }

    try {
      final response = await transport.get(
        IptvOrgRequest(
          uri: baseUri.resolve(endpoint.fileName),
          headers: Map.unmodifiable(headers),
        ),
      );
      if (response.statusCode == 304 && cached != null) {
        final refreshed = cached.refreshedAt(now);
        await cache.write(endpoint.name, refreshed);
        return (await _decode(endpoint, refreshed.body)).cast<T>();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw IptvOrgHttpException(response.statusCode, endpoint.name);
      }

      try {
        final decoded = await _decode(endpoint, response.body);
        await cache.write(
          endpoint.name,
          IptvOrgCacheEntry(
            body: response.body,
            fetchedAt: now,
            etag: response.header('etag'),
            lastModified: response.header('last-modified'),
          ),
        );
        return decoded.cast<T>();
      } on FormatException {
        if (cached != null) {
          return (await _decode(endpoint, cached.body)).cast<T>();
        }
        rethrow;
      }
    } on Object {
      if (cached != null) {
        return (await _decode(endpoint, cached.body)).cast<T>();
      }
      rethrow;
    }
  }

  Future<List<Object?>> _decode(
    IptvOrgEndpoint endpoint,
    Uint8List body,
  ) async {
    final input = (endpoint.index, body);
    final decoded = body.length > _offMainDecodeThresholdBytes
        ? await runOffMain(() => _decodeEndpointBytes(input))
        : _decodeEndpointBytes(input);
    return (decoded as List).cast<Object?>();
  }
}

Object _decodeEndpointBytes((int, Uint8List) input) {
  final endpoint = IptvOrgEndpoint.values[input.$1];
  return decodeIptvOrgEndpoint(endpoint, jsonDecode(utf8.decode(input.$2)));
}
