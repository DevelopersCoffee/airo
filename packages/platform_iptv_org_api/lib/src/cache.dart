import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

final class IptvOrgCacheEntry {
  const IptvOrgCacheEntry({
    required this.body,
    required this.fetchedAt,
    this.etag,
    this.lastModified,
  });

  final Uint8List body;
  final DateTime fetchedAt;
  final String? etag;
  final String? lastModified;

  IptvOrgCacheEntry refreshedAt(DateTime value) => IptvOrgCacheEntry(
    body: body,
    fetchedAt: value,
    etag: etag,
    lastModified: lastModified,
  );
}

abstract interface class IptvOrgCache {
  Future<IptvOrgCacheEntry?> read(String key);

  Future<void> write(String key, IptvOrgCacheEntry entry);
}

final class MemoryIptvOrgCache implements IptvOrgCache {
  final Map<String, IptvOrgCacheEntry> _entries = {};

  @override
  Future<IptvOrgCacheEntry?> read(String key) async => _entries[key];

  @override
  Future<void> write(String key, IptvOrgCacheEntry entry) async {
    _entries[key] = entry;
  }
}

/// File cache using same-directory temporary files and atomic rename.
final class FileIptvOrgCache implements IptvOrgCache {
  FileIptvOrgCache(this.directory);

  final Directory directory;

  @override
  Future<IptvOrgCacheEntry?> read(String key) async {
    final bodyFile = File(_bodyPath(key));
    final metadataFile = File(_metadataPath(key));
    if (!await bodyFile.exists() || !await metadataFile.exists()) return null;
    try {
      final metadata =
          jsonDecode(await metadataFile.readAsString()) as Map<String, Object?>;
      return IptvOrgCacheEntry(
        body: await bodyFile.readAsBytes(),
        fetchedAt: DateTime.parse(metadata['fetched_at']! as String).toUtc(),
        etag: metadata['etag'] as String?,
        lastModified: metadata['last_modified'] as String?,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String key, IptvOrgCacheEntry entry) async {
    await directory.create(recursive: true);
    final suffix = '.tmp-${DateTime.now().microsecondsSinceEpoch}';
    final bodyTemp = File('${_bodyPath(key)}$suffix');
    final metadataTemp = File('${_metadataPath(key)}$suffix');
    await bodyTemp.writeAsBytes(entry.body, flush: true);
    await metadataTemp.writeAsString(
      jsonEncode({
        'fetched_at': entry.fetchedAt.toUtc().toIso8601String(),
        'etag': entry.etag,
        'last_modified': entry.lastModified,
      }),
      flush: true,
    );
    await _atomicReplace(bodyTemp, File(_bodyPath(key)));
    await _atomicReplace(metadataTemp, File(_metadataPath(key)));
  }

  String _bodyPath(String key) => '${directory.path}/$key.body';

  String _metadataPath(String key) => '${directory.path}/$key.metadata.json';

  Future<void> _atomicReplace(File source, File target) async {
    if (await target.exists()) await target.delete();
    await source.rename(target.path);
  }
}
