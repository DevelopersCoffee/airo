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
  });

  final String name;
  final String url;
  final String? logo;
  final String? group;
  final String? tvgId;
  final String? tvgName;
  final String? language;
}

List<NativeM3uEntry> parseM3uEntries(String content) {
  return _dartParseM3uEntries(content);
}

Future<List<NativeM3uEntry>> parseM3uEntriesNative(String content) async {
  if (kIsWeb) return _dartParseM3uEntries(content);
  if (!await initializeCoreNativeBridge()) return _dartParseM3uEntries(content);
  try {
    final result = await native_m3u.parseM3UEntries(content: content);
    return result.map(_fromNativeM3uEntry).toList(growable: false);
  } on Object {
    return _dartParseM3uEntries(content);
  }
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
  );
}

List<NativeM3uEntry> _dartParseM3uEntries(String content) {
  final entries = <NativeM3uEntry>[];
  _PendingM3uEntry? pending;

  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.startsWith('#EXTINF:')) {
      pending = _parseExtInf(line);
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
      ),
    );
    pending = null;
  }

  return entries;
}

_PendingM3uEntry? _parseExtInf(String line) {
  final commaIndex = line.lastIndexOf(',');
  if (commaIndex == -1) return null;

  final attributes = line.substring(0, commaIndex);
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

  return _PendingM3uEntry(
    name: line.substring(commaIndex + 1).trim(),
    logo: result['tvg-logo'],
    group: result['group-title'],
    tvgId: result['tvg-id'],
    tvgName: result['tvg-name'],
    language: result['tvg-language'],
  );
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
  });

  final String name;
  final String? logo;
  final String? group;
  final String? tvgId;
  final String? tvgName;
  final String? language;
}
