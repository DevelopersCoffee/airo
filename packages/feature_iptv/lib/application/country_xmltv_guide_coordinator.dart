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
  bool _busy = false;
  String? _queued;

  Future<void> sync({required String? country}) async {
    final code = country?.trim();
    if (code == null || code.isEmpty) return;
    _queued = code;
    if (_busy) return;
    _busy = true;
    try {
      while (_queued != null) {
        final next = _queued!;
        _queued = null;
        final sources = await sourceStore.loadAll();
        if (sources.any((source) => source.kind == XmltvSourceKind.user)) {
          return;
        }
        try {
          if (_lastFetchedCountry == next.toUpperCase()) continue;
          await refreshCountryShard(next);
          _lastFetchedCountry = next.toUpperCase();
        } catch (_) {
          if (_queued == null) rethrow;
        }
      }
    } finally {
      _busy = false;
    }
  }
}
