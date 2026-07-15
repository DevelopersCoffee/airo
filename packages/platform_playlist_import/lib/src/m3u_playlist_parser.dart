import 'package:platform_channels/channel_search.dart';

/// Parse M3U content into normalized, deduplicated IPTV channels using the
/// Dart fallback parser. This keeps host-only benchmark tools free from
/// Flutter/native runtime imports.
List<IPTVChannel> parseM3UDartChannels(String content) {
  final channels = <IPTVChannel>[];
  final seenChannels = <String, IPTVChannel>{};

  for (final entry in _parseM3uEntries(content)) {
    final streamUri = AiroPlaylistUrlPolicy.normalizeStreamUrl(entry.url);
    if (streamUri == null) {
      continue;
    }

    final normalizedName = _normalizeChannelName(entry.name);
    final logoUri = AiroPlaylistUrlPolicy.normalizeLogoUrl(entry.logo);

    final channel = IPTVChannel.fromM3U(
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
      if (existing.logoUrl == null && channel.logoUrl != null) {
        seenChannels[normalizedName] = channel;
      }
    }
  }

  channels.addAll(seenChannels.values);
  return channels;
}

List<_ParsedM3uEntry> _parseM3uEntries(String content) {
  final entries = <_ParsedM3uEntry>[];
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
      _ParsedM3uEntry(
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

/// Normalize channel name for deduplication (lowercase, remove special chars).
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

/// Format channel name for display (proper capitalization).
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

bool _isWhitespace(int codeUnit) {
  return codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0B ||
      codeUnit == 0x0C ||
      codeUnit == 0x0D;
}

bool _isAttributeKeyCode(int codeUnit) {
  return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
      codeUnit == 0x5F ||
      codeUnit == 0x2D;
}

class _ParsedM3uEntry {
  const _ParsedM3uEntry({
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
