import 'package:flutter/foundation.dart';

/// Whether the Runtime Console (surface 13) renders on this platform.
///
/// Windows, Linux, and macOS ship the dense operator table for local
/// verification (`replayFrom`, #1216). Phone/tablet/web/TV use lighter surfaces.
bool isRuntimeConsolePlatform([TargetPlatform? platform]) {
  if (kIsWeb) return false;
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}
