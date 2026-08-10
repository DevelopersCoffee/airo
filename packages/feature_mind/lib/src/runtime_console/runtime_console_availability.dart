import 'package:flutter/foundation.dart';

/// Whether the Runtime Console (surface 13) renders on this platform.
///
/// The design puts the dense operator table on Windows and Linux only — macOS
/// takes the platform-chrome "Everything Browser" instead (surface 8), and
/// phone/tablet/web/TV never get a 12,000-row signed log table at all.
/// Mirrors the platform-gating shape in `mind_availability.dart`: a plain
/// function over `defaultTargetPlatform` rather than a widget that silently
/// renders nothing, so a caller can branch on it before building anything.
bool isRuntimeConsolePlatform([TargetPlatform? platform]) {
  if (kIsWeb) return false;
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.macOS:
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}
