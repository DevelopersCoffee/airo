import 'package:flutter/services.dart';

/// Device capabilities for direct, user-authorized local media browsing.
class LocalMediaLibraryCapabilities {
  const LocalMediaLibraryCapabilities({
    required this.removableStorage,
    required this.dlnaUpnp,
  });

  const LocalMediaLibraryCapabilities.unsupported()
    : removableStorage = false,
      dlnaUpnp = false;

  final bool removableStorage;
  final bool dlnaUpnp;
}

enum LocalMediaEntryKind { folder, video, audio, subtitle }

class LocalMediaAccessException implements Exception {
  const LocalMediaAccessException(this.code);

  /// Stable, privacy-safe code. Native exception text is intentionally
  /// discarded because it can contain document or network identifiers.
  final String code;

  @override
  String toString() => 'LocalMediaAccessException($code)';
}

/// An opaque local-library entry. [accessUri] is deliberately excluded from
/// [toString] so content URIs, LAN addresses, and filenames cannot leak into
/// diagnostics.
class LocalMediaEntry {
  const LocalMediaEntry({
    required this.id,
    required this.name,
    required this.kind,
    required this.accessUri,
    this.childrenUri,
    this.subtitleUri,
  });

  final String id;
  final String name;
  final LocalMediaEntryKind kind;
  final String accessUri;
  final String? childrenUri;
  final String? subtitleUri;

  bool get isPlayable =>
      kind == LocalMediaEntryKind.video || kind == LocalMediaEntryKind.audio;

  @override
  String toString() =>
      'LocalMediaEntry(id: $id, kind: ${kind.name}, accessUri: redacted)';
}

abstract interface class LocalMediaLibraryAdapter {
  Future<LocalMediaLibraryCapabilities> capabilities();

  /// Opens the platform's explicit permission surface. Returns an opaque root
  /// URI, or null when the user cancels.
  Future<String?> requestRemovableStorageRoot();

  Future<List<LocalMediaEntry>> browse(String rootUri);
}

/// Android Storage Access Framework adapter. Unsupported platforms naturally
/// report false through MissingPluginException rather than showing dead UI.
class AndroidLocalMediaLibraryAdapter implements LocalMediaLibraryAdapter {
  const AndroidLocalMediaLibraryAdapter({
    this.channel = const MethodChannel('io.airo.local_media'),
  });

  final MethodChannel channel;

  @override
  Future<LocalMediaLibraryCapabilities> capabilities() async {
    try {
      final raw = await channel.invokeMapMethod<String, Object?>(
        'capabilities',
      );
      return LocalMediaLibraryCapabilities(
        removableStorage: raw?['removableStorage'] == true,
        dlnaUpnp: raw?['dlnaUpnp'] == true,
      );
    } on MissingPluginException {
      return const LocalMediaLibraryCapabilities.unsupported();
    } on PlatformException {
      return const LocalMediaLibraryCapabilities.unsupported();
    }
  }

  @override
  Future<String?> requestRemovableStorageRoot() async {
    try {
      return await channel.invokeMethod<String>('requestRemovableStorage');
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      throw LocalMediaAccessException(
        error.code == 'permission_denied'
            ? 'permission_denied'
            : 'picker_unavailable',
      );
    }
  }

  @override
  Future<List<LocalMediaEntry>> browse(String rootUri) async {
    final rows =
        await channel.invokeListMethod<Map<Object?, Object?>>(
          'browseRemovableStorage',
          <String, Object?>{'rootUri': rootUri},
        ) ??
        const [];
    final entries = rows.map(_decodeLocalMediaEntry).toList(growable: false);
    return associateLocalSidecarSubtitles(entries);
  }
}

/// Adds a same-basename subtitle to a playable item without exposing the
/// underlying URI. Matching is deterministic and case-insensitive.
List<LocalMediaEntry> associateLocalSidecarSubtitles(
  List<LocalMediaEntry> entries,
) {
  final subtitles = <String, String>{
    for (final entry in entries)
      if (entry.kind == LocalMediaEntryKind.subtitle)
        _basename(entry.name): entry.accessUri,
  };
  return [
    for (final entry in entries)
      if (entry.kind != LocalMediaEntryKind.subtitle)
        LocalMediaEntry(
          id: entry.id,
          name: entry.name,
          kind: entry.kind,
          accessUri: entry.accessUri,
          childrenUri: entry.childrenUri,
          subtitleUri: entry.isPlayable
              ? subtitles[_basename(entry.name)]
              : null,
        ),
  ];
}

String _basename(String name) {
  final dot = name.lastIndexOf('.');
  return (dot <= 0 ? name : name.substring(0, dot)).toLowerCase();
}

/// Discovery/browse boundary for standards-based local-network media servers.
abstract interface class DlnaUpnpLibraryAdapter {
  Future<List<LocalMediaEntry>> discover();
  Future<List<LocalMediaEntry>> browse(String containerUri);
}

/// Android SSDP/UPnP adapter backed by the product host's native channel.
///
/// The native implementation retains server control URLs in memory and gives
/// Dart opaque `dlna://` container handles. Playable HTTP resource URLs cross
/// the boundary only when the user chooses a media item, and neither this
/// adapter nor [LocalMediaEntry.toString] logs them.
class AndroidDlnaUpnpLibraryAdapter implements DlnaUpnpLibraryAdapter {
  const AndroidDlnaUpnpLibraryAdapter({
    this.channel = const MethodChannel('io.airo.local_media'),
  });

  final MethodChannel channel;

  @override
  Future<List<LocalMediaEntry>> discover() async {
    final rows =
        await channel.invokeListMethod<Map<Object?, Object?>>('discoverDlna') ??
        const [];
    return rows.map(_decodeLocalMediaEntry).toList(growable: false);
  }

  @override
  Future<List<LocalMediaEntry>> browse(String containerUri) async {
    final rows =
        await channel.invokeListMethod<Map<Object?, Object?>>(
          'browseDlna',
          <String, Object?>{'containerUri': containerUri},
        ) ??
        const [];
    return associateLocalSidecarSubtitles(
      rows.map(_decodeLocalMediaEntry).toList(growable: false),
    );
  }
}

LocalMediaEntry _decodeLocalMediaEntry(Map<Object?, Object?> row) {
  final id = row['id'];
  final name = row['name'];
  final accessUri = row['accessUri'];
  if (id is! String ||
      id.isEmpty ||
      name is! String ||
      name.isEmpty ||
      accessUri is! String ||
      accessUri.isEmpty) {
    throw const FormatException('Invalid local-media entry.');
  }
  final rawKind = row['kind'];
  if (rawKind is! String) {
    throw const FormatException('Invalid local-media entry kind.');
  }
  final kind = switch (rawKind) {
    'folder' => LocalMediaEntryKind.folder,
    'video' => LocalMediaEntryKind.video,
    'audio' => LocalMediaEntryKind.audio,
    'subtitle' => LocalMediaEntryKind.subtitle,
    _ => throw const FormatException('Invalid local-media entry kind.'),
  };
  return LocalMediaEntry(
    id: id,
    name: name,
    kind: kind,
    accessUri: accessUri,
    childrenUri: row['childrenUri'] as String?,
  );
}

/// Stable, privacy-safe identifier for local playback history and resume.
///
/// Dart's `String.hashCode` is not a persistence contract. FNV-1a keeps the
/// opaque platform identifier out of stored channel ids while producing the
/// same value across launches and builds.
String stableLocalMediaChannelId(String opaqueEntryId) {
  var hash = 0xcbf29ce484222325;
  for (final codeUnit in opaqueEntryId.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
  }
  return 'local-${hash.toRadixString(16).padLeft(16, '0')}';
}
