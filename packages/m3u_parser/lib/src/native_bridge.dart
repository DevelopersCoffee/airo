import 'package:flutter/foundation.dart' show kIsWeb;

import 'frb_generated.dart' as frb;

bool _initialized = false;
Future<bool>? _initializing;

/// Initializes the Rust bridge. Returns `false` on web (no native bridge
/// exists there) or when the native library fails to load, so callers can
/// fall back to the pure-Dart parser deterministically.
Future<bool> initializeM3uParserBridge() async {
  if (kIsWeb) return false;
  if (_initialized) return true;

  final existing = _initializing;
  if (existing != null) return existing;

  return _initializing = () async {
    try {
      await frb.RustLib.init();
      _initialized = true;
      return true;
    } on Object {
      return false;
    } finally {
      _initializing = null;
    }
  }();
}
