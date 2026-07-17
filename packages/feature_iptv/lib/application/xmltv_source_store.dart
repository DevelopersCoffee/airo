import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:equatable/equatable.dart';

/// A user-configured XMLTV guide source: the URL, when it was last
/// successfully refreshed, and the last error (if any) — drives the
/// stale/unavailable UI state per CV-015 slice 2.
class XmltvSourceConfig extends Equatable {
  const XmltvSourceConfig({
    required this.url,
    this.lastRefreshedAt,
    this.lastError,
  });

  final String url;
  final DateTime? lastRefreshedAt;
  final String? lastError;

  XmltvSourceConfig copyWith({
    String? url,
    DateTime? Function()? lastRefreshedAt,
    String? Function()? lastError,
  }) {
    return XmltvSourceConfig(
      url: url ?? this.url,
      lastRefreshedAt: lastRefreshedAt != null
          ? lastRefreshedAt()
          : this.lastRefreshedAt,
      lastError: lastError != null ? lastError() : this.lastError,
    );
  }

  factory XmltvSourceConfig.fromJson(Map<String, dynamic> json) {
    return XmltvSourceConfig(
      url: json['url'] as String,
      lastRefreshedAt: json['lastRefreshedAt'] != null
          ? DateTime.parse(json['lastRefreshedAt'] as String)
          : null,
      lastError: json['lastError'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    if (lastRefreshedAt != null)
      'lastRefreshedAt': lastRefreshedAt!.toIso8601String(),
    if (lastError != null) 'lastError': lastError,
  };

  @override
  List<Object?> get props => [url, lastRefreshedAt, lastError];
}

/// Persists the single configured XMLTV source (this slice supports one
/// active source, matching the issue's "add/remove/refresh **an** XMLTV
/// URL" scope — not a multi-source list).
class XmltvSourceStore {
  XmltvSourceStore(this._store);

  static const String _storageKey = 'xmltv_source_config';

  final KeyValueStore _store;

  Future<void> save(XmltvSourceConfig config) async {
    await _store.setString(_storageKey, jsonEncode(config.toJson()));
  }

  Future<XmltvSourceConfig?> load() async {
    final json = await _store.getString(_storageKey);
    if (json == null) return null;
    return XmltvSourceConfig.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> clear() async {
    await _store.remove(_storageKey);
  }

  Future<void> recordRefreshSuccess(DateTime refreshedAt) async {
    final current = await load();
    if (current == null) return;
    await save(
      current.copyWith(lastRefreshedAt: () => refreshedAt, lastError: () => null),
    );
  }

  Future<void> recordRefreshError(String error) async {
    final current = await load();
    if (current == null) return;
    await save(current.copyWith(lastError: () => error));
  }
}
