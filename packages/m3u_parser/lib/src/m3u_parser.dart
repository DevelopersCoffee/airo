import 'package:flutter/foundation.dart' show kIsWeb;

import 'api/m3u.dart' as native_m3u;
import 'native_bridge.dart';

class M3uEntry {
  const M3uEntry({
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
class M3uPlaylist {
  const M3uPlaylist({required this.entries, required this.headers});

  final List<M3uEntry> entries;
  final Map<String, String> headers;
}

/// Aggregate-only parser telemetry. Never contains a source URL, channel
/// name, or other playlist content, so it's safe to log or report.
class M3uParseStats {
  const M3uParseStats({
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

class M3uParseResult {
  const M3uParseResult({required this.playlist, required this.stats});

  final M3uPlaylist playlist;
  final M3uParseStats stats;
}

class M3uChannel {
  const M3uChannel({
    required this.name,
    required this.url,
    this.logo,
    this.group,
    this.tvgId,
    this.tvgName,
    this.language,
    this.aliases = const [],
    this.country,
    this.provider,
    this.tags = const [],
  });

  final String name;
  final String url;
  final String? logo;
  final String? group;
  final String? tvgId;
  final String? tvgName;
  final String? language;
  final List<String> aliases;
  final String? country;
  final String? provider;
  final List<String> tags;
}

class M3uChannelParseResult {
  const M3uChannelParseResult({required this.channels, required this.stats});

  final List<M3uChannel> channels;
  final M3uParseStats stats;
}

/// Parse M3U content (entries + `#EXTM3U` header attributes) with the
/// synchronous, pure-Dart parser. This is the deterministic/test/web path
/// and never touches the native bridge — prefer [parseM3uAsync] when you
/// want Rust acceleration with automatic fallback.
///
/// This package spawns no isolates internally: parses over ~50 KB should be
/// wrapped in your own off-main boundary by the caller.
M3uPlaylist parseM3u(String content) => parseM3uWithStats(content).playlist;

/// Synchronous, pure-Dart parse with aggregate stats.
M3uParseResult parseM3uWithStats(String content) =>
    _dartParseM3uWithStats(content);

/// Synchronous, pure-Dart parse into validated, normalized, deduplicated
/// channel records.
M3uChannelParseResult parseM3uChannelsWithStats(String content) =>
    _dartChannelsFromResult(_dartParseM3uWithStats(content));

/// Parse M3U content through the Rust core parser, falling back to the
/// identical Dart implementation on web or when the native bridge is
/// unavailable.
Future<M3uPlaylist> parseM3uAsync(String content) async =>
    (await parseM3uWithStatsAsync(content)).playlist;

/// Parse and retain aggregate stats through Rust, falling back to the
/// identical Dart implementation when unavailable.
Future<M3uParseResult> parseM3uWithStatsAsync(String content) async {
  if (kIsWeb) {
    return _dartParseM3uWithStats(content);
  }
  if (!await initializeM3uParserBridge()) {
    return _dartParseM3uWithStats(content);
  }
  try {
    final result = await native_m3u.parseM3UWithStats(content: content);
    return M3uParseResult(
      playlist: M3uPlaylist(
        entries: result.playlist.entries.map(_fromNative).toList(),
        headers: result.playlist.headers,
      ),
      stats: M3uParseStats(
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
    return _dartParseM3uWithStats(content);
  }
}

/// Parse, validate, normalize, and deduplicate M3U channels through Rust,
/// falling back to identical Dart behavior when unavailable.
Future<M3uChannelParseResult> parseM3uChannelsWithStatsAsync(
  String content,
) async {
  if (kIsWeb) {
    return _dartChannelsFromResult(_dartParseM3uWithStats(content));
  }
  if (!await initializeM3uParserBridge()) {
    return _dartChannelsFromResult(_dartParseM3uWithStats(content));
  }
  try {
    final result = await native_m3u.parseM3UChannelsWithStats(
      content: content,
    );
    return M3uChannelParseResult(
      channels: result.channels.map(_fromNativeChannel).toList(),
      stats: M3uParseStats(
        parsedCount: result.stats.parsedCount,
        skippedCount: result.stats.skippedCount,
        malformedCount: result.stats.malformedCount,
        // ignore: noop_primitive_operations
        elapsedMillis: result.stats.elapsedMillis.toInt(),
      ),
    );
  } on Object {
    return _dartChannelsFromResult(_dartParseM3uWithStats(content));
  }
}

M3uEntry _fromNative(native_m3u.M3uEntry entry) => M3uEntry(
  name: entry.name,
  url: entry.url,
  logo: entry.logo,
  group: entry.group,
  tvgId: entry.tvgId,
  tvgName: entry.tvgName,
  language: entry.language,
  // ignore: noop_primitive_operations
  duration: entry.duration?.toInt(),
  extras: entry.extras,
);

M3uChannel _fromNativeChannel(native_m3u.M3uChannel channel) => M3uChannel(
  name: channel.name,
  url: channel.url,
  logo: channel.logo,
  group: channel.group,
  tvgId: channel.tvgId,
  tvgName: channel.tvgName,
  language: channel.language,
  aliases: channel.aliases,
  country: channel.country,
  provider: channel.provider,
  tags: channel.tags,
);

M3uChannelParseResult _dartChannelsFromResult(M3uParseResult result) {
  final channels = <M3uChannel>[];
  final seenChannels = <String, M3uChannel>{};

  for (final entry in result.playlist.entries) {
    final streamUri = _normalizeNetworkUrl(entry.url);
    if (streamUri == null) continue;

    final normalizedName = _normalizeChannelName(entry.name);
    final logoUri = entry.logo == null
        ? null
        : _normalizeNetworkUrl(entry.logo!);
    final aliases = {
      if (entry.tvgName?.trim().isNotEmpty ?? false) entry.tvgName!.trim(),
      if (entry.tvgId?.trim().isNotEmpty ?? false) entry.tvgId!.trim(),
    }.toList(growable: false);

    final channel = M3uChannel(
      name: _formatChannelName(entry.name),
      url: streamUri,
      logo: logoUri,
      group: entry.group,
      tvgId: entry.tvgId,
      tvgName: entry.tvgName,
      language: entry.language,
      aliases: aliases,
      country: _firstExtra(entry.extras, const ['tvg-country', 'country']),
      provider: _firstExtra(entry.extras, const ['provider', 'tvg-provider']),
      tags: _listExtra(entry.extras, const ['tvg-tags', 'tags']),
    );

    final existing = seenChannels[normalizedName];
    if (existing == null) {
      seenChannels[normalizedName] = channel;
    } else if (existing.logo == null && channel.logo != null) {
      seenChannels[normalizedName] = channel;
    }
  }

  channels.addAll(seenChannels.values);
  return M3uChannelParseResult(channels: channels, stats: result.stats);
}

/// Mirrors the Rust `first_extra`: find the FIRST key (in order) that is
/// *present* in the map (regardless of whether its value is empty), then
/// trim that one value. Does not fall through to later keys once a present
/// key is found, even if its trimmed value is empty.
String? _firstExtra(Map<String, String> extras, List<String> keys) {
  for (final key in keys) {
    final value = extras[key];
    if (value != null) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
  }
  return null;
}

/// Mirrors the Rust `list_extra`: iterate ALL the given keys that are
/// present (not just the first), split each on `,`/`;`/`|`, trim each
/// piece, and union everything into one deduped list in first-seen order.
List<String> _listExtra(Map<String, String> extras, List<String> keys) {
  final values = <String>[];
  for (final key in keys) {
    final raw = extras[key];
    if (raw == null) continue;
    for (final piece in raw.split(RegExp('[,;|]'))) {
      final value = piece.trim();
      if (value.isNotEmpty && !values.contains(value)) {
        values.add(value);
      }
    }
  }
  return values;
}

M3uParseResult _dartParseM3uWithStats(String content) {
  final stopwatch = Stopwatch()..start();
  final entries = <M3uEntry>[];
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
      M3uEntry(
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
  return M3uParseResult(
    playlist: M3uPlaylist(entries: entries, headers: headers),
    stats: M3uParseStats(
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

String? _normalizeNetworkUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri == null || !_isAllowedNetworkUri(uri)) return null;
  return raw;
}

bool _isAllowedNetworkUri(Uri uri) {
  if (!uri.hasScheme || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    return false;
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') {
    return false;
  }

  return !_isPrivateOrLocalHost(uri.host);
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
