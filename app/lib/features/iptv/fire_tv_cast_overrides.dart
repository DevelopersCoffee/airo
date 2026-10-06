import 'dart:async';

import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/misc.dart';

/// Google Cast sender/receiver SDKs require Google Play services. Fire OS
/// builds omit those native dependencies, so Cast UI stays visible but routes
/// through unavailable transports instead of crashing on plugin init.
List<Override> fireTvCastProviderOverrides() {
  return [
    airoCastControllerProvider.overrideWith((ref) {
      final controller = UnavailableAiroCastController();
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    }),
    multiviewCastSenderTransportProvider.overrideWith(
      (ref) => const UnavailableMultiviewCastSenderTransport(),
    ),
    multiviewCastReceiverTransportProvider.overrideWith(
      (ref) => const UnavailableMultiviewCastReceiverTransport(),
    ),
  ];
}
