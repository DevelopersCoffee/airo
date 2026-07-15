import 'package:flutter/foundation.dart' show kIsWeb;

import 'frb_generated.dart' as frb;

/// Normalize a channel name for deduplication and search.
///
/// Delegates to the Rust implementation when the native library is loaded.
/// Falls back to pure Dart on web, in tests, or before RustLib.init() runs.
String normalizeChannelName(String name) {
  if (kIsWeb) return _dartNormalize(name);
  try {
    return frb.normalizeChannelName(name: name);
  } on Exception {
    return _dartNormalize(name);
  }
}

// Pure-Dart fallback: semantically identical to the Rust implementation.
String _dartNormalize(String name) =>
    name.replaceAll(RegExp('[^a-zA-Z0-9]'), '').toLowerCase();
