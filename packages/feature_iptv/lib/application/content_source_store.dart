import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:equatable/equatable.dart';
import 'package:platform_playlist/platform_playlist.dart';

/// A user-configured content source, in storage-shaped form. [url] covers
/// both [M3uContentSource.playlistUrl] and the `serverUrl` field the
/// Xtream/Stalker/Jellyfin variants share. [macAddress] is Stalker-only.
/// Xtream/Jellyfin credentials are never stored here — they live in
/// [ContentSourceCredentialStore], looked up via
/// `ContentSourceCredentialRef(id)` at [toContentSource] time.
class ContentSourceConfig extends Equatable {
  const ContentSourceConfig({
    required this.id,
    required this.kind,
    required this.label,
    required this.url,
    this.macAddress,
  });

  final String id;
  final ContentSourceKind kind;
  final String label;
  final String url;
  final String? macAddress;

  factory ContentSourceConfig.fromJson(Map<String, dynamic> json) {
    return ContentSourceConfig(
      id: json['id'] as String,
      kind: ContentSourceKind.values.firstWhere(
        (k) => k.stableId == json['kind'] as String,
      ),
      label: json['label'] as String,
      url: json['url'] as String,
      macAddress: json['macAddress'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.stableId,
    'label': label,
    'url': url,
    if (macAddress != null) 'macAddress': macAddress,
  };

  /// Builds the concrete [ContentSource] this config describes. Xtream and
  /// Jellyfin sources' credentials are NOT included here — the returned
  /// source only carries a [ContentSourceCredentialRef], never the raw
  /// secret; callers needing to authenticate must separately read
  /// [ContentSourceCredentialStore] using that same ref.
  ContentSource toContentSource() {
    switch (kind) {
      case ContentSourceKind.m3u:
        return M3uContentSource(id: id, label: label, playlistUrl: url);
      case ContentSourceKind.xtream:
        return XtreamContentSource(
          id: id,
          label: label,
          serverUrl: url,
          credentialRef: ContentSourceCredentialRef(id),
        );
      case ContentSourceKind.stalker:
        return StalkerContentSource(
          id: id,
          label: label,
          serverUrl: url,
          macAddress: macAddress ?? '',
        );
      case ContentSourceKind.jellyfin:
        return JellyfinContentSource(
          id: id,
          label: label,
          serverUrl: url,
          credentialRef: ContentSourceCredentialRef(id),
        );
    }
  }

  @override
  List<Object?> get props => [id, kind, label, url, macAddress];
}

/// Persists the list of content sources a user has configured. Same
/// `KeyValueStore`-wrapping pattern as `XmltvSourceStore`
/// (`packages/feature_iptv/lib/application/xmltv_source_store.dart`), scaled
/// to a list rather than a single value.
class ContentSourceStore {
  ContentSourceStore(this._store);

  static const String _storageKey = 'content_sources';

  final KeyValueStore _store;

  Future<List<ContentSourceConfig>> getAll() async {
    final json = await _store.getString(_storageKey);
    if (json == null) return [];
    final decoded = jsonDecode(json) as List;
    return decoded
        .map(
          (item) => ContentSourceConfig.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> add(ContentSourceConfig config) async {
    final all = await getAll();
    all.add(config);
    await _save(all);
  }

  Future<void> remove(String id) async {
    final all = await getAll();
    all.removeWhere((c) => c.id == id);
    await _save(all);
  }

  Future<void> _save(List<ContentSourceConfig> configs) async {
    await _store.setString(
      _storageKey,
      jsonEncode(configs.map((c) => c.toJson()).toList()),
    );
  }
}
