import 'dart:convert';

import 'package:core_workers/core_workers.dart';

const String kAiroBackupSchema = 'airo.tv.backup';
const int kAiroBackupVersion = 1;
const int kAiroBackupWorkerThresholdBytes = 50 * 1024;
const int kAiroBackupMaximumBytes = 10 * 1024 * 1024;

class AiroBackupSource {
  const AiroBackupSource({
    required this.id,
    required this.url,
    required this.label,
    this.metadata = const {},
  });

  final String id;
  final String url;
  final String label;
  final Map<String, String> metadata;

  Map<String, Object> toMap() => {
    'id': id,
    'url': url,
    'label': label,
    'metadata': Map.fromEntries(
      metadata.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ),
  };
}

class AiroBackupFavorite {
  const AiroBackupFavorite({
    required this.channelId,
    required this.name,
    required this.url,
    this.group,
  });

  final String channelId;
  final String name;
  final String url;
  final String? group;

  Map<String, Object?> toMap() => {
    'channelId': channelId,
    'name': name,
    'url': url,
    'group': group,
  };
}

class AiroBackupSnapshot {
  AiroBackupSnapshot({
    required Iterable<AiroBackupSource> playlistSources,
    required Iterable<AiroBackupFavorite> favorites,
    required Iterable<AiroBackupSource> epgSources,
    required Map<String, String> settings,
  }) : playlistSources = List.unmodifiable(playlistSources),
       favorites = List.unmodifiable(favorites),
       epgSources = List.unmodifiable(epgSources),
       settings = Map.unmodifiable(settings);

  final List<AiroBackupSource> playlistSources;
  final List<AiroBackupFavorite> favorites;
  final List<AiroBackupSource> epgSources;
  final Map<String, String> settings;

  Map<String, Object> toMap() {
    final playlists = [...playlistSources]
      ..sort((a, b) => a.id.compareTo(b.id));
    final favoriteRows = [...favorites]
      ..sort((a, b) => a.channelId.compareTo(b.channelId));
    final epg = [...epgSources]..sort((a, b) => a.id.compareTo(b.id));
    return {
      'schema': kAiroBackupSchema,
      'version': kAiroBackupVersion,
      'playlistSources': playlists.map((value) => value.toMap()).toList(),
      'favorites': favoriteRows.map((value) => value.toMap()).toList(),
      'epgSources': epg.map((value) => value.toMap()).toList(),
      'settings': Map.fromEntries(
        settings.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      ),
    };
  }
}

enum AiroBackupRejection {
  oversized,
  malformed,
  unsupportedSchema,
  invalidRecord,
  conflictingRecord,
}

class AiroBackupException implements Exception {
  const AiroBackupException(this.code);

  final AiroBackupRejection code;
}

class AiroBackupCodec {
  const AiroBackupCodec();

  Future<String> encode(AiroBackupSnapshot snapshot) async {
    _validateSnapshot(snapshot);
    final map = snapshot.toMap();
    final estimatedBytes = utf8.encode(jsonEncode(map)).length;
    if (estimatedBytes > kAiroBackupMaximumBytes) {
      throw const AiroBackupException(AiroBackupRejection.oversized);
    }
    return estimatedBytes > kAiroBackupWorkerThresholdBytes
        ? runOffMain(() => _canonicalJson(map))
        : _canonicalJson(map);
  }

  Future<AiroBackupSnapshot> decode(String contents) async {
    final bytes = utf8.encode(contents).length;
    if (bytes > kAiroBackupMaximumBytes) {
      throw const AiroBackupException(AiroBackupRejection.oversized);
    }
    final Object? decoded;
    try {
      decoded = bytes > kAiroBackupWorkerThresholdBytes
          ? await runOffMain(() => jsonDecode(contents))
          : jsonDecode(contents);
    } on FormatException {
      throw const AiroBackupException(AiroBackupRejection.malformed);
    }
    final snapshot = _snapshotFrom(decoded);
    _validateSnapshot(snapshot);
    return snapshot;
  }
}

class AiroBackupPreview {
  const AiroBackupPreview({
    required this.merged,
    required this.playlistAdditions,
    required this.favoriteAdditions,
    required this.epgAdditions,
    required this.settingChanges,
  });

  final AiroBackupSnapshot merged;
  final int playlistAdditions;
  final int favoriteAdditions;
  final int epgAdditions;
  final int settingChanges;
}

class AiroBackupMerger {
  const AiroBackupMerger();

  AiroBackupPreview preview({
    required AiroBackupSnapshot current,
    required AiroBackupSnapshot incoming,
    required Set<String> recognizedSettingKeys,
  }) {
    final playlists = _mergeSources(
      current.playlistSources,
      incoming.playlistSources,
    );
    final epg = _mergeSources(current.epgSources, incoming.epgSources);
    final favorites = <String, AiroBackupFavorite>{
      for (final value in current.favorites) value.channelId: value,
    };
    for (final value in incoming.favorites) {
      final existing = favorites[value.channelId];
      if (existing != null && !_sameFavorite(existing, value)) {
        throw const AiroBackupException(AiroBackupRejection.conflictingRecord);
      }
      favorites[value.channelId] = value;
    }
    final settings = {...current.settings};
    var settingChanges = 0;
    for (final entry in incoming.settings.entries) {
      if (!recognizedSettingKeys.contains(entry.key)) continue;
      if (settings[entry.key] != entry.value) settingChanges++;
      settings[entry.key] = entry.value;
    }
    final orderedFavorites = favorites.values.toList()
      ..sort((a, b) => a.channelId.compareTo(b.channelId));
    return AiroBackupPreview(
      merged: AiroBackupSnapshot(
        playlistSources: playlists,
        favorites: orderedFavorites,
        epgSources: epg,
        settings: settings,
      ),
      playlistAdditions: playlists.length - current.playlistSources.length,
      favoriteAdditions: favorites.length - current.favorites.length,
      epgAdditions: epg.length - current.epgSources.length,
      settingChanges: settingChanges,
    );
  }

  List<AiroBackupSource> _mergeSources(
    List<AiroBackupSource> current,
    List<AiroBackupSource> incoming,
  ) {
    final result = <String, AiroBackupSource>{};
    for (final source in [...current, ...incoming]) {
      final key = _normalizedUrl(source.url);
      final existing = result[key];
      if (existing != null && existing.id != source.id) {
        continue;
      }
      result[key] = source;
    }
    return result.values.toList()
      ..sort((a, b) => _normalizedUrl(a.url).compareTo(_normalizedUrl(b.url)));
  }
}

abstract interface class AiroBackupStateStore {
  Future<AiroBackupSnapshot> read();

  Future<void> replaceAtomically(AiroBackupSnapshot snapshot);
}

class AiroBackupService {
  const AiroBackupService({
    required this.store,
    this.codec = const AiroBackupCodec(),
    this.merger = const AiroBackupMerger(),
    this.recognizedSettingKeys = const {},
  });

  final AiroBackupStateStore store;
  final AiroBackupCodec codec;
  final AiroBackupMerger merger;
  final Set<String> recognizedSettingKeys;

  Future<String> export() async => codec.encode(await store.read());

  Future<AiroBackupPreview> previewImport(String contents) async {
    final incoming = await codec.decode(contents);
    return merger.preview(
      current: await store.read(),
      incoming: incoming,
      recognizedSettingKeys: recognizedSettingKeys,
    );
  }

  Future<void> apply(AiroBackupPreview preview) =>
      store.replaceAtomically(preview.merged);
}

class AiroBackupDocument {
  const AiroBackupDocument({
    required this.fileName,
    required this.mediaType,
    required this.contents,
  });

  final String fileName;
  final String mediaType;
  final String contents;
}

abstract interface class AiroBackupDocumentGateway {
  Future<void> save(AiroBackupDocument document);

  Future<void> share(AiroBackupDocument document);

  /// Returns null when the platform picker is cancelled.
  Future<AiroBackupDocument?> pick();
}

class AiroBackupDocumentController {
  const AiroBackupDocumentController({
    required this.service,
    required this.documents,
  });

  final AiroBackupService service;
  final AiroBackupDocumentGateway documents;

  Future<void> saveBackup() async {
    await documents.save(await _backupDocument());
  }

  Future<void> shareBackup() async {
    await documents.share(await _backupDocument());
  }

  Future<AiroBackupPreview?> pickAndPreview() async {
    final document = await documents.pick();
    if (document == null) return null;
    return service.previewImport(document.contents);
  }

  Future<AiroBackupDocument> _backupDocument() async {
    return AiroBackupDocument(
      fileName: 'airo_tv_backup_v$kAiroBackupVersion.json',
      mediaType: 'application/json',
      contents: await service.export(),
    );
  }
}

String exportFavoritesM3u(Iterable<AiroBackupFavorite> favorites) {
  final ordered = favorites.toList()
    ..sort((a, b) => a.channelId.compareTo(b.channelId));
  final output = StringBuffer('#EXTM3U\n');
  for (final favorite in ordered) {
    final name = _singleLine(favorite.name);
    final group = favorite.group == null
        ? ''
        : ' group-title="${_attribute(favorite.group!)}"';
    output
      ..writeln(
        '#EXTINF:-1 tvg-id="${_attribute(favorite.channelId)}"$group,$name',
      )
      ..writeln(_singleLine(favorite.url));
  }
  return output.toString();
}

AiroBackupSnapshot _snapshotFrom(Object? value) {
  if (value is! Map<String, Object?> ||
      value['schema'] != kAiroBackupSchema ||
      value['version'] != kAiroBackupVersion) {
    throw const AiroBackupException(AiroBackupRejection.unsupportedSchema);
  }
  try {
    return AiroBackupSnapshot(
      playlistSources: _sources(value['playlistSources']),
      favorites: _favorites(value['favorites']),
      epgSources: _sources(value['epgSources']),
      settings: Map<String, String>.from(value['settings']! as Map),
    );
  } on AiroBackupException {
    rethrow;
  } on Object {
    throw const AiroBackupException(AiroBackupRejection.invalidRecord);
  }
}

List<AiroBackupSource> _sources(Object? value) {
  final rows = value as List;
  return [
    for (final Object? item in rows)
      AiroBackupSource(
        id: _requiredText((item as Map)['id']),
        url: _validUrl((item)['url']),
        label: _requiredText((item)['label']),
        metadata: Map<String, String>.from(
          item['metadata'] as Map? ?? const {},
        ),
      ),
  ];
}

List<AiroBackupFavorite> _favorites(Object? value) {
  final rows = value as List;
  return [
    for (final Object? item in rows)
      AiroBackupFavorite(
        channelId: _requiredText((item as Map)['channelId']),
        name: _requiredText(item['name']),
        url: _validUrl(item['url']),
        group: item['group'] as String?,
      ),
  ];
}

String _canonicalJson(Map<String, Object> value) => jsonEncode(value);

String _requiredText(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const AiroBackupException(AiroBackupRejection.invalidRecord);
  }
  return value;
}

String _validUrl(Object? value) {
  final text = _requiredText(value);
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw const AiroBackupException(AiroBackupRejection.invalidRecord);
  }
  return text;
}

String _normalizedUrl(String value) {
  final uri = Uri.parse(value.trim());
  return uri
      .replace(scheme: uri.scheme.toLowerCase(), host: uri.host.toLowerCase())
      .toString();
}

bool _sameFavorite(AiroBackupFavorite left, AiroBackupFavorite right) =>
    left.name == right.name &&
    _normalizedUrl(left.url) == _normalizedUrl(right.url) &&
    left.group == right.group;

void _validateSnapshot(AiroBackupSnapshot snapshot) {
  _validateSources(snapshot.playlistSources);
  _validateSources(snapshot.epgSources);
  final favorites = <String, AiroBackupFavorite>{};
  for (final favorite in snapshot.favorites) {
    _requiredText(favorite.channelId);
    _requiredText(favorite.name);
    _validUrl(favorite.url);
    final existing = favorites[favorite.channelId];
    if (existing != null && !_sameFavorite(existing, favorite)) {
      throw const AiroBackupException(AiroBackupRejection.conflictingRecord);
    }
    favorites[favorite.channelId] = favorite;
  }
}

void _validateSources(List<AiroBackupSource> sources) {
  final ids = <String, AiroBackupSource>{};
  final urls = <String, AiroBackupSource>{};
  for (final source in sources) {
    _requiredText(source.id);
    _requiredText(source.label);
    if (source.metadata.entries.any((entry) => entry.key.trim().isEmpty)) {
      throw const AiroBackupException(AiroBackupRejection.invalidRecord);
    }
    final url = _normalizedUrl(_validUrl(source.url));
    final byId = ids[source.id];
    if (byId != null && _normalizedUrl(byId.url) != url) {
      throw const AiroBackupException(AiroBackupRejection.conflictingRecord);
    }
    final byUrl = urls[url];
    if (byUrl != null && byUrl.id != source.id) {
      throw const AiroBackupException(AiroBackupRejection.conflictingRecord);
    }
    ids[source.id] = source;
    urls[url] = source;
  }
}

String _singleLine(String value) =>
    value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

String _attribute(String value) => _singleLine(value).replaceAll(r'"', r'\"');
