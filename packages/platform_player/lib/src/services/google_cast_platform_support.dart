import 'package:flutter/foundation.dart';

/// Google Cast sender support currently ships through the Android/iOS sender
/// SDK bridge. Desktop support needs a deliberate native sender, AirPlay, or
/// custom receiver design instead of reusing the mobile controller.
bool get isGoogleCastSenderPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
