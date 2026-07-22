import 'package:flutter/foundation.dart' show kIsWeb;

import 'api/m3u.dart' as native_m3u;
import 'm3u_file_reader_stub.dart'
    if (dart.library.io) 'm3u_file_reader_io.dart';
import 'native_bridge.dart';

class NativeM3uEntry {
  const NativeM3uEntry({
    required this.name,
    required this.url,
    this.logo,
    this.group,
    this.tvgId,
    this.tvgName,
    this.language,
    this.duration,
    this.extras = const {},
  });

  final String name;
  final String url;
  final String? logo;
  final String? group;
  final String? tvgId;
  final String? tvgName;
  final String? language;

  /// EXTINF duration in seconds. `-1` means live/unknown; a positive value
  /// indicates VOD. Null when absent or unparseable.
  final int? duration;

  /// EXTINF attributes outside the known set (e.g. `tvg-chno`,
  /// `catchup-days`, `radio`), preserved instead of dropped.
  final Map<String, String> extras;
}

/// Full parse result: channel entries plus attributes from the `#EXTM3U`
/// header line (e.g. `x-tvg-url` / `url-tvg` EPG source URLs).
class NativeM3uPlaylist {
  const NativeM3uPlaylist({required this.entries, required this.headers});

  final List<NativeM3uEntry> entries;
  final Map<String, String> headers;
}

/// Redacted aggregate parser telemetry for playlist import progress. It never
/// contains a user-supplied source URL or individual channel data.
class NativeM3uParseStats {
  const NativeM3uParseStats({
    required this.parsedCount,
    required this.skippedCount,
    required this.malformedCount,
    required this.elapsedMillis,
  });

  final int parsedCount;
  final int skippedCount;
  final int malformedCount;
  final int elapsedMillis;
}

class NativeM3uParseResult {
  const NativeM3uParseResult({required this.playlist, required this.stats});

  final NativeM3uPlaylist playlist;
  final NativeM3uParseStats stats;
}

class NativeM3uChannel {
  const NativeM3uChannel({
    required this.name,
    required this.url,
    this.logo,
    this.group,
    this.tvgId,
    this.tvgName,
    this.language,
  });

  final String name;
  final String url;
  final String? logo;
  final String? group;
  final String? tvgId;
  final String? tvgName;
  final String? language;
}

class NativeM3uChannelParseResult {
  const NativeM3uChannelParseResult({
    required this.channels,
    required this.stats,
  });

  final List<NativeM3uChannel> channels;
  final NativeM3uParseStats stats;
}

/// Parse M3U channel entries with the synchronous Dart fallback parser.
///
/// This is the web fallback and the deterministic-test path; native
/// production parsing should prefer [parseM3uEntriesNative].
List<NativeM3uEntry> parseM3uEntries(String content) =>
    parseM3uPlaylist(content).entries;

/// Parse M3U channel entries through the Rust core parser, falling back to
/// the Dart parser on web or when the native bridge is unavailable.
Future<List<NativeM3uEntry>> parseM3uEntriesNative(String content) async =>
    (await parseM3uPlaylistNative(content)).entries;

/// Parse M3U content (entries + `#EXTM3U` header attributes) with the
/// synchronous Dart fallback parser. Web fallback / deterministic-test path;
/// prefer [parseM3uPlaylistNative] on native platforms.
NativeM3uPlaylist parseM3uPlaylist(String content) =>
    parseM3uPlaylistWithStats(content).playlist;

/// Synchronous Dart fallback with redacted aggregate counters. Production
/// native callers should use [parseM3uPlaylistWithStatsNative].
NativeM3uParseResult parseM3uPlaylistWithStats(String content) =>
    _dartParseM3uPlaylistWithStats(content);

/// Parse M3U content into validated, normalized, deduplicated channel records
/// with the synchronous Dart fallback path.
NativeM3uChannelParseResult parseM3uChannelsWithStats(String content) =>
    _dartParseM3uChannelsWithStats(content);

/// Parse M3U content (entries + `#EXTM3U` header attributes) through the
/// Rust core parser, falling back to the Dart parser on web or when the
/// native bridge is unavailable.
Future<NativeM3uPlaylist> parseM3uPlaylistNative(String content) async {
  return (await parseM3uPlaylistWithStatsNative(content)).playlist;
}

/// Parse M3U content and safe aggregate parser telemetry through Rust,
/// falling back to the deterministic Dart parser when unavailable.
Future<NativeM3uParseResult> parseM3uPlaylistWithStatsNative(
  String content,
) async {
  if (kIsWeb) {
    return _dartParseM3uPlaylistWithStats(content);
  }
  if (!await initializeCoreNativeBridge()) {
    return _dartParseM3uPlaylistWithStats(content);
  }
  try {
    final result = await native_m3u.parseM3UWithStats(content: content);
    return NativeM3uParseResult(
      playlist: _fromNativeM3uPlaylist(result.playlist),
      stats: NativeM3uParseStats(
        parsedCount: result.stats.parsedCount,
        skippedCount: result.stats.skippedCount,
        malformedCount: result.stats.malformedCount,
        // PlatformInt64 is int on IO and BigInt on web. Native execution is
        // the only path here, but the conversion keeps web builds compiling.
        // ignore: noop_primitive_operations
        elapsedMillis: result.stats.elapsedMillis.toInt(),
      ),
    );
  } on Object {
    return _dartParseM3uPlaylistWithStats(content);
  }
}

/// Parse M3U content into validated, normalized, deduplicated channel records
/// through Rust, falling back to identical Dart behavior when unavailable.
Future<NativeM3uChannelParseResult> parseM3uChannelsWithStatsNative(
  String content,
) async {
  if (kIsWeb) {
    return _dartParseM3uChannelsWithStats(content);
  }
  if (!await initializeCoreNativeBridge()) {
    return _dartParseM3uChannelsWithStats(content);
  }
  try {
    final result = await native_m3u.parseM3UChannelsWithStats(content: content);
    return _fromNativeM3uChannelParseResult(result);
  } on Object {
    return _dartParseM3uChannelsWithStats(content);
  }
}

/// Parse an M3U file through the Rust core parser, falling back to the
/// deterministic Dart parser when the native bridge is unavailable.
Future<NativeM3uParseResult> parseM3uPlaylistFileWithStatsNative(
  String path,
) async {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    throw ArgumentError.value(path, 'path', 'must not be empty');
  }
  if (kIsWeb) {
    throw UnsupportedError(
      'M3U file parsing is not available on web. '
      'Use parseM3uPlaylistWithStats with M3U content instead.',
    );
  }
  if (!await initializeCoreNativeBridge()) {
    return _dartParseM3uPlaylistWithStats(readM3uFileSync(normalizedPath));
  }
  try {
    final result = await native_m3u.parseM3UFileWithStats(path: normalizedPath);
    return NativeM3uParseResult(
      playlist: _fromNativeM3uPlaylist(result.playlist),
      stats: NativeM3uParseStats(
        parsedCount: result.stats.parsedCount,
        skippedCount: result.stats.skippedCount,
        malformedCount: result.stats.malformedCount,
        // ignore: noop_primitive_operations
        elapsedMillis: result.stats.elapsedMillis.toInt(),
      ),
    );
  } on Object {
    return _dartParseM3uPlaylistWithStats(readM3uFileSync(normalizedPath));
  }
}

/// Parse an M3U file into validated, normalized, deduplicated channel records
/// through Rust, falling back to identical Dart behavior when unavailable.
Future<NativeM3uChannelParseResult> parseM3uFileChannelsWithStatsNative(
  String path,
) async {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    throw ArgumentError.value(path, 'path', 'must not be empty');
  }
  if (kIsWeb) {
    throw UnsupportedError(
      'M3U file channel parsing is not available on web. '
      'Use parseM3uChannelsWithStats with M3U content instead.',
    );
  }
  if (!await initializeCoreNativeBridge()) {
    return _dartParseM3uChannelsWithStats(readM3uFileSync(normalizedPath));
  }
  try {
    final result = await native_m3u.parseM3UFileChannelsWithStats(
      path: normalizedPath,
    );
    return _fromNativeM3uChannelParseResult(result);
  } on Object {
    return _dartParseM3uChannelsWithStats(readM3uFileSync(normalizedPath));
  }
}

NativeM3uPlaylist _fromNativeM3uPlaylist(native_m3u.M3uPlaylist playlist) {
  return NativeM3uPlaylist(
    entries: playlist.entries.map(_fromNativeM3uEntry).toList(growable: false),
    headers: playlist.headers,
  );
}

NativeM3uChannelParseResult _fromNativeM3uChannelParseResult(
  native_m3u.M3uChannelParseResult result,
) {
  return NativeM3uChannelParseResult(
    channels: result.channels
        .map(_fromNativeM3uChannel)
        .toList(growable: false),
    stats: NativeM3uParseStats(
      parsedCount: result.stats.parsedCount,
      skippedCount: result.stats.skippedCount,
      malformedCount: result.stats.malformedCount,
      // ignore: noop_primitive_operations
      elapsedMillis: result.stats.elapsedMillis.toInt(),
    ),
  );
}

NativeM3uChannel _fromNativeM3uChannel(native_m3u.M3uChannel channel) {
  return NativeM3uChannel(
    name: channel.name,
    url: channel.url,
    logo: channel.logo,
    group: channel.group,
    tvgId: channel.tvgId,
    tvgName: channel.tvgName,
    language: channel.language,
  );
}

NativeM3uEntry _fromNativeM3uEntry(native_m3u.M3uEntry entry) {
  return NativeM3uEntry(
    name: entry.name,
    url: entry.url,
    logo: entry.logo,
    group: entry.group,
    tvgId: entry.tvgId,
    tvgName: entry.tvgName,
    language: entry.language,
    // PlatformInt64 is `int` on IO and `BigInt` on web; this mapping only
    // runs on native platforms but must still compile for web.
    // ignore: noop_primitive_operations
    duration: entry.duration?.toInt(),
    extras: entry.extras,
  );
}

NativeM3uChannelParseResult _dartParseM3uChannelsWithStats(String content) {
  final result = _dartParseM3uPlaylistWithStats(content);
  return NativeM3uChannelParseResult(
    channels: _channelsFromM3uEntries(result.playlist.entries),
    stats: result.stats,
  );
}

List<NativeM3uChannel> _channelsFromM3uEntries(
  Iterable<NativeM3uEntry> entries,
) {
  final channels = <NativeM3uChannel>[];
  final seenChannels = <String, NativeM3uChannel>{};

  for (final entry in entries) {
    final streamUri = _normalizeStreamUrl(entry.url);
    if (streamUri == null) {
      continue;
    }

    final normalizedName = _normalizeChannelName(entry.name);
    final logoUri = _normalizeLogoUrl(entry.logo);

    final channel = NativeM3uChannel(
      name: _formatChannelName(entry.name),
      url: streamUri.toString(),
      logo: logoUri?.toString(),
      group: entry.group,
      tvgId: entry.tvgId,
      tvgName: entry.tvgName,
      language: entry.language,
    );

    if (!seenChannels.containsKey(normalizedName)) {
      seenChannels[normalizedName] = channel;
    } else {
      final existing = seenChannels[normalizedName]!;
      if (existing.logo == null && channel.logo != null) {
        seenChannels[normalizedName] = channel;
      }
    }
  }

  channels.addAll(seenChannels.values);
  return channels;
}

NativeM3uParseResult _dartParseM3uPlaylistWithStats(String content) {
  final stopwatch = Stopwatch()..start();
  final entries = <NativeM3uEntry>[];
  final headers = <String, String>{};
  _PendingM3uEntry? pending;
  var skippedCount = 0;
  var malformedCount = 0;

  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.startsWith('#EXTINF:')) {
      if (pending != null) {
        skippedCount++;
      }
      final parsed = _parseExtInf(line);
      if (parsed == null) {
        malformedCount++;
      }
      pending = parsed;
      continue;
    }

    if (line.startsWith('#EXTM3U')) {
      headers.addAll(_parseAttributes(line.substring('#EXTM3U'.length)));
      continue;
    }

    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }

    final info = pending;
    if (info == null) continue;

    entries.add(
      NativeM3uEntry(
        name: info.name,
        url: line,
        logo: info.logo,
        group: info.group,
        tvgId: info.tvgId,
        tvgName: info.tvgName,
        language: info.language,
        duration: info.duration,
        extras: info.extras,
      ),
    );
    pending = null;
  }

  if (pending != null) {
    skippedCount++;
  }
  stopwatch.stop();
  return NativeM3uParseResult(
    playlist: NativeM3uPlaylist(entries: entries, headers: headers),
    stats: NativeM3uParseStats(
      parsedCount: entries.length,
      skippedCount: skippedCount,
      malformedCount: malformedCount,
      elapsedMillis: stopwatch.elapsedMilliseconds,
    ),
  );
}

_PendingM3uEntry? _parseExtInf(String line) {
  final commaIndex = line.lastIndexOf(',');
  if (commaIndex == -1) return null;

  final head = line.substring('#EXTINF:'.length, commaIndex).trimLeft();
  final durationTokenEnd = _indexOfWhitespace(head);
  final durationToken = durationTokenEnd == -1
      ? head
      : head.substring(0, durationTokenEnd);
  final duration = int.tryParse(durationToken);

  final attributes = _parseAttributes(line.substring(0, commaIndex));
  final extras = Map<String, String>.of(attributes)
    ..remove('tvg-logo')
    ..remove('group-title')
    ..remove('tvg-id')
    ..remove('tvg-name')
    ..remove('tvg-language');

  return _PendingM3uEntry(
    name: line.substring(commaIndex + 1).trim(),
    logo: attributes['tvg-logo'],
    group: attributes['group-title'],
    tvgId: attributes['tvg-id'],
    tvgName: attributes['tvg-name'],
    language: attributes['tvg-language'],
    duration: duration,
    extras: extras,
  );
}

int _indexOfWhitespace(String value) {
  for (var index = 0; index < value.length; index++) {
    final codeUnit = value.codeUnitAt(index);
    if (codeUnit == 0x20 || codeUnit == 0x09) {
      return index;
    }
  }
  return -1;
}

/// Scan `key="value"` attribute pairs, mirroring the Rust `AttributeIter`.
Map<String, String> _parseAttributes(String attributes) {
  final result = <String, String>{};
  var index = 0;

  while (index < attributes.length) {
    while (index < attributes.length &&
        !_isAttributeKeyCode(attributes.codeUnitAt(index))) {
      index++;
    }

    final keyStart = index;
    while (index < attributes.length &&
        _isAttributeKeyCode(attributes.codeUnitAt(index))) {
      index++;
    }

    if (keyStart == index || index + 1 >= attributes.length) {
      continue;
    }

    if (attributes.codeUnitAt(index) != 0x3D ||
        attributes.codeUnitAt(index + 1) != 0x22) {
      continue;
    }

    final key = attributes.substring(keyStart, index);
    index += 2;
    final valueStart = index;
    while (index < attributes.length && attributes.codeUnitAt(index) != 0x22) {
      index++;
    }
    if (index >= attributes.length) break;

    result[key] = attributes.substring(valueStart, index);
    index++;
  }

  return result;
}

bool _isAttributeKeyCode(int codeUnit) {
  return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
      codeUnit == 0x5F ||
      codeUnit == 0x2D;
}

Uri? _normalizeStreamUrl(String? value) => _normalizeNetworkUrl(value);

Uri? _normalizeLogoUrl(String? value) => _normalizeNetworkUrl(value);

Uri? _normalizeNetworkUrl(
  String? value, {
  bool allowHttp = true,
  bool allowPrivateHosts = false,
}) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !_isAllowedNetworkUri(
        uri,
        allowHttp: allowHttp,
        allowPrivateHosts: allowPrivateHosts,
      )) {
    return null;
  }
  return uri;
}

bool _isAllowedNetworkUri(
  Uri uri, {
  required bool allowHttp,
  required bool allowPrivateHosts,
}) {
  if (!uri.hasScheme || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    return false;
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && !(allowHttp && scheme == 'http')) {
    return false;
  }

  if (!allowPrivateHosts && _isPrivateOrLocalHost(uri.host)) {
    return false;
  }

  return true;
}

bool _isPrivateOrLocalHost(String host) {
  final normalized = host.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  if (normalized == 'localhost' || normalized.endsWith('.localhost')) {
    return true;
  }
  if (normalized.endsWith('.local')) return true;

  final ipv4 = _parseIpv4(normalized);
  if (ipv4 != null) {
    final first = ipv4[0];
    final second = ipv4[1];
    return first == 0 ||
        first == 10 ||
        first == 127 ||
        (first == 100 && second >= 64 && second <= 127) ||
        (first == 169 && second == 254) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168) ||
        first >= 224;
  }

  if (normalized.contains(':')) {
    return normalized == '::' ||
        normalized == '::1' ||
        normalized == '0:0:0:0:0:0:0:1' ||
        normalized.startsWith('fe80:') ||
        normalized.startsWith('fc') ||
        normalized.startsWith('fd');
  }

  return false;
}

List<int>? _parseIpv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return null;

  final octets = <int>[];
  for (final part in parts) {
    if (part.isEmpty) return null;
    final octet = int.tryParse(part);
    if (octet == null || octet < 0 || octet > 255) {
      return null;
    }
    octets.add(octet);
  }
  return octets;
}

String _normalizeChannelName(String name) {
  final buffer = StringBuffer();
  for (var i = 0; i < name.length; i++) {
    final codeUnit = name.codeUnitAt(i);

    if (codeUnit >= 0x30 && codeUnit <= 0x39) {
      buffer.writeCharCode(codeUnit);
    } else if (codeUnit >= 0x41 && codeUnit <= 0x5A) {
      buffer.writeCharCode(codeUnit + 0x20);
    } else if (codeUnit >= 0x61 && codeUnit <= 0x7A) {
      buffer.writeCharCode(codeUnit);
    }
  }
  return buffer.toString();
}

String _formatChannelName(String name) {
  final buffer = StringBuffer();
  var index = 0;

  while (index < name.length) {
    while (index < name.length && _isWhitespace(name.codeUnitAt(index))) {
      index++;
    }
    if (index >= name.length) break;

    final wordStart = index;
    while (index < name.length && !_isWhitespace(name.codeUnitAt(index))) {
      index++;
    }

    if (buffer.isNotEmpty) {
      buffer.write(' ');
    }

    final word = name.substring(wordStart, index);
    if (word.length <= 4 && word == word.toUpperCase()) {
      buffer.write(word);
    } else {
      buffer
        ..write(word[0].toUpperCase())
        ..write(word.substring(1).toLowerCase());
    }
  }

  return buffer.toString();
}

bool _isWhitespace(int codeUnit) => codeUnit == 0x20 || codeUnit == 0x09;

class _PendingM3uEntry {
  const _PendingM3uEntry({
    required this.name,
    this.logo,
    this.group,
    this.tvgId,
    this.tvgName,
    this.language,
    this.duration,
    this.extras = const {},
  });

  final String name;
  final String? logo;
  final String? group;
  final String? tvgId;
  final String? tvgName;
  final String? language;
  final int? duration;
  final Map<String, String> extras;
}
