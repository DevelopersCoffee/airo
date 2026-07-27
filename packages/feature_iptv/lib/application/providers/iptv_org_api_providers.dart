import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:platform_iptv_org_api/platform_iptv_org_api.dart';

/// Host-overridable typed iptv-org client with a native last-good disk cache.
///
/// The provider is lazy: no third-party request occurs until a consumer
/// explicitly watches a derived iptv-org provider.
final iptvOrgApiClientProvider = FutureProvider<IptvOrgApiClient>((ref) async {
  final support = await getApplicationSupportDirectory();
  return IptvOrgApiClient(
    transport: IoIptvOrgTransport(),
    cache: FileIptvOrgCache(Directory('${support.path}/iptv_org_api_v1')),
  );
});

/// Typed taxonomy proof path used by channel filters and regional discovery.
final iptvOrgTaxonomyProvider = FutureProvider<IptvOrgTaxonomy>((ref) async {
  final client = await ref.watch(iptvOrgApiClientProvider.future);
  final categories = client.fetchCategories();
  final languages = client.fetchLanguages();
  final countries = client.fetchCountries();
  final subdivisions = client.fetchSubdivisions();
  final cities = client.fetchCities();
  final regions = client.fetchRegions();
  final timezones = client.fetchTimezones();
  return IptvOrgTaxonomy(
    categories: await categories,
    languages: await languages,
    countries: await countries,
    subdivisions: await subdivisions,
    cities: await cities,
    regions: await regions,
    timezones: await timezones,
  );
});

final iptvOrgCountryByCodeProvider = Provider<Map<String, IptvOrgCountry>>((
  ref,
) {
  final taxonomy = ref.watch(iptvOrgTaxonomyProvider).value;
  if (taxonomy == null) return const {};
  return Map.unmodifiable({
    for (final country in taxonomy.countries)
      country.code.toUpperCase(): country,
  });
});

final iptvOrgLanguageByCodeProvider = Provider<Map<String, IptvOrgLanguage>>((
  ref,
) {
  final taxonomy = ref.watch(iptvOrgTaxonomyProvider).value;
  if (taxonomy == null) return const {};
  return Map.unmodifiable({
    for (final language in taxonomy.languages)
      language.code.toLowerCase(): language,
  });
});

final class IptvOrgTaxonomy {
  IptvOrgTaxonomy({
    required List<IptvOrgCategory> categories,
    required List<IptvOrgLanguage> languages,
    required List<IptvOrgCountry> countries,
    required List<IptvOrgSubdivision> subdivisions,
    required List<IptvOrgCity> cities,
    required List<IptvOrgRegion> regions,
    required List<IptvOrgTimezone> timezones,
  }) : categories = List.unmodifiable(categories),
       languages = List.unmodifiable(languages),
       countries = List.unmodifiable(countries),
       subdivisions = List.unmodifiable(subdivisions),
       cities = List.unmodifiable(cities),
       regions = List.unmodifiable(regions),
       timezones = List.unmodifiable(timezones);

  final List<IptvOrgCategory> categories;
  final List<IptvOrgLanguage> languages;
  final List<IptvOrgCountry> countries;
  final List<IptvOrgSubdivision> subdivisions;
  final List<IptvOrgCity> cities;
  final List<IptvOrgRegion> regions;
  final List<IptvOrgTimezone> timezones;
}
