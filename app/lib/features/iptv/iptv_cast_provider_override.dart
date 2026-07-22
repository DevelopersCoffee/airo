import 'dart:async';

import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/misc.dart';

Override realIptvCastControllerOverride() {
  return airoCastControllerProvider.overrideWith((ref) {
    final controller = isGoogleCastSenderPlatform
        ? FlutterChromeCastController(useProxy: true)
        : UnavailableAiroCastController();
    ref.onDispose(() => unawaited(controller.dispose()));
    return controller;
  });
}
