import 'package:flutter/foundation.dart' show kIsWeb;

import 'frb_generated.dart' as frb;

bool _initialized = false;
Future<bool>? _initializing;

Future<bool> initializeCoreNativeBridge() async {
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
