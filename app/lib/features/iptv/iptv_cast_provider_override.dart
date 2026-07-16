import 'dart:async';

import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

Override realIptvCastControllerOverride() {
  return airoCastControllerProvider.overrideWith((ref) {
    final controller = kIsWeb
        ? UnavailableAiroCastController()
        : FlutterChromeCastController(useProxy: true);
    ref.onDispose(() => unawaited(controller.dispose()));
    return controller;
  });
}
