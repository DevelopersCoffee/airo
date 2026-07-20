import 'package:flutter/foundation.dart' show kIsWeb;

import 'api/m3u.dart' as native_m3u;
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
    _dartParseM3uPlaylist(content);

/// Parse M3U content (entries + `#EXTM3U` header attributes) through the
/// Rust core parser, falling back to the Dart parser on web or when the
/// native bridge is unavailable.
Future<NativeM3uPlaylist> parseM3uPlaylistNative(String content) async {
  if (kIsWeb) {
    return _dartParseM3uPlaylist(content);
  }
  if (!await initializeCoreNativeBridge()) {
    return _dartParseM3uPlaylist(content);
  }
  try {
    final result = await native_m3u.parseM3UPlaylist(content: content);
    return _fromNativeM3uPlaylist(result);
  } on Object {
    return _dartParseM3uPlaylist(content);
  }
}

NativeM3uPlaylist _fromNativeM3uPlaylist(native_m3u.M3uPlaylist playlist) {
  return NativeM3uPlaylist(
    entries: playlist.entries.map(_fromNativeM3uEntry).toList(growable: false),
    headers: playlist.headers,
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

NativeM3uPlaylist _dartParseM3uPlaylist(String content) {
  final entries = <NativeM3uEntry>[];
  final headers = <String, String>{};
  _PendingM3uEntry? pending;

  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.startsWith('#EXTINF:')) {
      pending = _parseExtInf(line);
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

  return NativeM3uPlaylist(entries: entries, headers: headers);
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
