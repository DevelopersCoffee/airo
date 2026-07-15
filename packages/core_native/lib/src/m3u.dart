import 'package:flutter/foundation.dart' show kIsWeb;

// ignore: implementation_imports
import 'frb_generated.dart' as frb;

/// Parsed M3U channel entry returned by the native parser.
///
/// Mirrors the Rust `M3UEntry` struct.  The Dart consumer maps these into
/// `IPTVChannel` objects.
class NativeM3UEntry {
  final String name;
  final String url;
  final String groupTitle;
  final String tvgLogo;
  final String tvgId;
  final String tvgName;
  final String tvgLanguage;
  final String tvgCountry;

  const NativeM3UEntry({
    required this.name,
    required this.url,
    this.groupTitle = '',
    this.tvgLogo = '',
    this.tvgId = '',
    this.tvgName = '',
    this.tvgLanguage = '',
    this.tvgCountry = '',
  });
}

/// Parse M3U playlist content into a list of channel entries.
///
/// Delegates to the Rust implementation when the native library is loaded.
/// Falls back to a minimal pure-Dart parser on web, in tests, or before
/// `RustLib.init()` runs.
List<NativeM3UEntry> parseM3UNative(String content) {
  if (kIsWeb) return _dartParseM3U(content);
  try {
    final rustEntries = frb.parseM3U(content: content);
    return rustEntries
        .map((e) => NativeM3UEntry(
              name: e.name,
              url: e.url,
              groupTitle: e.groupTitle,
              tvgLogo: e.tvgLogo,
              tvgId: e.tvgId,
              tvgName: e.tvgName,
              tvgLanguage: e.tvgLanguage,
              tvgCountry: e.tvgCountry,
            ))
        .toList();
  } on UnsupportedError {
    return _dartParseM3U(content);
  }
}

// ── Pure-Dart fallback ────────────────────────────────────────────────

/// Minimal M3U parser — semantically identical to the Rust implementation.
List<NativeM3UEntry> _dartParseM3U(String content) {
  final entries = <NativeM3UEntry>[];
  final lines = content.split('\n');

  Map<String, String?>? pending;

  for (final rawLine in lines) {
    final line = rawLine.trim();

    if (line.startsWith('#EXTINF:')) {
      pending = _parseExtInf(line);
    } else if (line.isNotEmpty && !line.startsWith('#') && pending != null) {
      if (line.startsWith('http://') || line.startsWith('https://')) {
        entries.add(NativeM3UEntry(
          name: pending['name'] ?? '',
          url: line,
          groupTitle: pending['group-title'] ?? '',
          tvgLogo: pending['tvg-logo'] ?? '',
          tvgId: pending['tvg-id'] ?? '',
          tvgName: pending['tvg-name'] ?? '',
          tvgLanguage: pending['tvg-language'] ?? '',
          tvgCountry: pending['tvg-country'] ?? '',
        ));
      }
      pending = null;
    }
  }

  return entries;
}

/// Parse `#EXTINF:` line attributes.  Channel name is after the last
/// unquoted comma.
Map<String, String?> _parseExtInf(String line) {
  final result = <String, String?>{};

  // Find the last comma outside quotes for the channel name.
  var inQuotes = false;
  var lastComma = -1;
  for (var i = 0; i < line.length; i++) {
    if (line[i] == '"') {
      inQuotes = !inQuotes;
    } else if (line[i] == ',' && !inQuotes) {
      lastComma = i;
    }
  }

  if (lastComma != -1) {
    result['name'] = line.substring(lastComma + 1).trim();
  }

  // Extract key="value" pairs.
  final attrPattern = RegExp(r'([\w-]+)="([^"]*)"');
  for (final match in attrPattern.allMatches(line)) {
    result[match.group(1)!.toLowerCase()] = match.group(2);
  }

  return result;
}
