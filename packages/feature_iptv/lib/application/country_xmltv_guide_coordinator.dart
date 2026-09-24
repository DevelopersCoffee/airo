import 'xmltv_source_store.dart';

typedef RefreshCountryShard = Future<void> Function(String country);

class CountryXmltvGuideCoordinator {
  CountryXmltvGuideCoordinator({
    required this.sourceStore,
    required this.refreshCountryShard,
  });

  final XmltvSourceStore sourceStore;
  final RefreshCountryShard refreshCountryShard;

  String? _lastFetchedCountry;

  Future<void> sync({required String? country}) async {
    final code = country?.trim();
    if (code == null || code.isEmpty) return;
    final sources = await sourceStore.loadAll();
    if (sources.any((source) => source.kind == XmltvSourceKind.user)) {
      return;
    }
    if (_lastFetchedCountry == code.toUpperCase()) return;
    await refreshCountryShard(code);
    _lastFetchedCountry = code.toUpperCase();
  }
}
