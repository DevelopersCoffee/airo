import 'package:flutter/foundation.dart' show kIsWeb;

import 'api/text.dart' as native_text;
import 'native_bridge.dart';

/// Normalize a channel name for deduplication and search.
///
/// Delegates to the Rust implementation when the native library is loaded.
/// Falls back to pure Dart on web, in tests, or before RustLib.init() runs.
String normalizeChannelName(String name) {
  return _dartNormalize(name);
}

Future<String> normalizeChannelNameNative(String name) async {
  if (kIsWeb) return _dartNormalize(name);
  if (!await initializeCoreNativeBridge()) return _dartNormalize(name);
  try {
    return await native_text.normalizeChannelName(name: name);
  } on Object {
    return _dartNormalize(name);
  }
}

// Pure-Dart fallback: semantically identical to the Rust implementation.
String _dartNormalize(String name) =>
    name.replaceAll(RegExp('[^a-zA-Z0-9]'), '').toLowerCase();
