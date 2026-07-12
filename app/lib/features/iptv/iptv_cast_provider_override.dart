import 'dart:async';

import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Override realIptvCastControllerOverride() {
  return airoCastControllerProvider.overrideWith((ref) {
    final controller = FlutterChromeCastController();
    ref.onDispose(() => unawaited(controller.dispose()));
    return controller;
  });
}
