import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:equatable/equatable.dart';

enum XmltvSourceKind { system, user }

/// A user-configured XMLTV guide source: the URL, when it was last
/// successfully refreshed, and the last error (if any) — drives the
/// stale/unavailable UI state per CV-015 slice 2.
class XmltvSourceConfig extends Equatable {
  const XmltvSourceConfig({
    required this.url,
    this.kind = XmltvSourceKind.user,
    this.expectedSha256,
    this.lastRefreshedAt,
    this.lastError,
  });

  final String url;
  final XmltvSourceKind kind;
  final String? expectedSha256;
  final DateTime? lastRefreshedAt;
  final String? lastError;

  XmltvSourceConfig copyWith({
    String? url,
    XmltvSourceKind? kind,
    String? Function()? expectedSha256,
    DateTime? Function()? lastRefreshedAt,
    String? Function()? lastError,
  }) {
    return XmltvSourceConfig(
      url: url ?? this.url,
      kind: kind ?? this.kind,
      expectedSha256: expectedSha256 != null
          ? expectedSha256()
          : this.expectedSha256,
      lastRefreshedAt: lastRefreshedAt != null
          ? lastRefreshedAt()
          : this.lastRefreshedAt,
      lastError: lastError != null ? lastError() : this.lastError,
    );
  }

  factory XmltvSourceConfig.fromJson(Map<String, dynamic> json) {
    return XmltvSourceConfig(
      url: json['url'] as String,
      kind: XmltvSourceKind.values.firstWhere(
        (candidate) => candidate.name == json['kind'],
        orElse: () => XmltvSourceKind.user,
      ),
      expectedSha256: json['expectedSha256'] as String?,
      lastRefreshedAt: json['lastRefreshedAt'] != null
          ? DateTime.parse(json['lastRefreshedAt'] as String)
          : null,
      lastError: json['lastError'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'kind': kind.name,
    if (expectedSha256 != null) 'expectedSha256': expectedSha256,
    if (lastRefreshedAt != null)
      'lastRefreshedAt': lastRefreshedAt!.toIso8601String(),
    if (lastError != null) 'lastError': lastError,
  };

  @override
  List<Object?> get props => [
    url,
    kind,
    expectedSha256,
    lastRefreshedAt,
    lastError,
  ];
}

/// Persists ordered system/user XMLTV sources and migrates the legacy
/// single-source payload on first read.
class XmltvSourceStore {
  XmltvSourceStore(this._store);

  static const String _storageKey = 'xmltv_source_config';
  static const String _sourcesStorageKey = 'xmltv_source_configs_v2';

  final KeyValueStore _store;

  Future<void> save(XmltvSourceConfig config) async {
    final sources = await loadAll();
    final retained = [
      for (final source in sources)
        if (source.kind != config.kind) source,
    ];
    await saveAll([...retained, config]);
  }

  Future<XmltvSourceConfig?> load() async {
    final sources = await loadAll();
    return sources
            .where((source) => source.kind == XmltvSourceKind.user)
            .firstOrNull ??
        sources.firstOrNull;
  }

  Future<List<XmltvSourceConfig>> loadAll() async {
    final encodedSources = await _store.getString(_sourcesStorageKey);
    if (encodedSources != null) {
      final rows = jsonDecode(encodedSources) as List<dynamic>;
      return List.unmodifiable(
        rows.map(
          (row) => XmltvSourceConfig.fromJson(row as Map<String, dynamic>),
        ),
      );
    }
    final json = await _store.getString(_storageKey);
    if (json == null) return const [];
    final migrated = XmltvSourceConfig.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
    await saveAll([migrated]);
    await _store.remove(_storageKey);
    return [migrated];
  }

  Future<void> saveAll(Iterable<XmltvSourceConfig> configs) async {
    final ordered = configs.toList()
      ..sort((left, right) {
        final kind = left.kind.index.compareTo(right.kind.index);
        if (kind != 0) return kind;
        return left.url.compareTo(right.url);
      });
    await _store.setString(
      _sourcesStorageKey,
      jsonEncode([for (final config in ordered) config.toJson()]),
    );
  }

  Future<void> clear() async {
    final retained = [
      for (final source in await loadAll())
        if (source.kind != XmltvSourceKind.user) source,
    ];
    await _store.remove(_storageKey);
    if (retained.isEmpty) {
      await _store.remove(_sourcesStorageKey);
    } else {
      await saveAll(retained);
    }
  }

  Future<void> recordRefreshSuccess(
    DateTime refreshedAt, {
    XmltvSourceKind kind = XmltvSourceKind.user,
  }) async {
    final current = (await loadAll())
        .where((source) => source.kind == kind)
        .firstOrNull;
    if (current == null) return;
    await save(
      current.copyWith(
        lastRefreshedAt: () => refreshedAt,
        lastError: () => null,
      ),
    );
  }

  Future<void> recordRefreshError(
    String error, {
    XmltvSourceKind kind = XmltvSourceKind.user,
  }) async {
    final current = (await loadAll())
        .where((source) => source.kind == kind)
        .firstOrNull;
    if (current == null) return;
    await save(current.copyWith(lastError: () => error));
  }
}
