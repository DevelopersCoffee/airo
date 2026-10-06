/// Deep link / NFC NDEF entry points for frictionless expense capture.
///
/// Tags should encode a URI record pointing at [nfcExpenseCaptureUri]. Android
/// routes NDEF_DISCOVERED and VIEW intents; tests and CI can open the same URI
/// with `adb shell am start -a android.intent.action.VIEW -d …`.
class NfcExpenseCaptureLink {
  const NfcExpenseCaptureLink._();

  static const String scheme = 'airo';
  static const String host = 'coins';
  static const String path = '/quick-capture';

  static const String httpsHost = 'developerscoffee.github.io';
  static const String httpsPathPrefix = '/airo/coins/quick-capture';

  /// Canonical URI written to NFC tags and used in Android intent filters.
  static final Uri nfcExpenseCaptureUri = Uri(
    scheme: scheme,
    host: host,
    path: path,
  );

  static final Uri httpsExpenseCaptureUri = Uri(
    scheme: 'https',
    host: httpsHost,
    path: httpsPathPrefix,
  );

  /// Returns true when [uri] should open the three-step quick capture flow.
  static bool matches(Uri uri) {
    if (uri.scheme == scheme && uri.host == host) {
      return _pathMatches(uri.path);
    }
    if (uri.scheme == 'https' && uri.host == httpsHost) {
      return uri.path == httpsPathPrefix || uri.path == '$httpsPathPrefix/';
    }
    return false;
  }

  static bool _pathMatches(String rawPath) {
    if (rawPath.isEmpty || rawPath == '/') return false;
    final normalized = rawPath.endsWith('/') && rawPath.length > 1
        ? rawPath.substring(0, rawPath.length - 1)
        : rawPath;
    return normalized == path;
  }

  /// Parses a platform intent string (full URI or path-only) into a match flag.
  static bool matchesString(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    if (uri.scheme.isEmpty) {
      return trimmed == path ||
          trimmed == httpsPathPrefix ||
          trimmed.endsWith(path);
    }
    return matches(uri);
  }
}
