import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart';

/// Real receiver transport only exists on Airo TV's own Android build —
/// [AiroCastReceiverMultiviewTransport] talks to native Kotlin
/// (`AiroCastReceiverMultiviewPlugin`) that only compiles into the `tv`
/// variant (see `app/android/app/build.gradle.kts`'s `isTvVariant` gate on
/// `play-services-cast-tv`). Dev/test only — the receiver app (F353F9C7) is
/// unpublished, reachable only from a registered test device; see
/// docs/superpowers/specs/2026-09-07-cast-multiview-remote-control-spec.md.
Override realCastMultiviewReceiverOverride() {
  return multiviewCastReceiverTransportProvider.overrideWith((ref) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const UnavailableMultiviewCastReceiverTransport();
    }
    return AiroCastReceiverMultiviewTransport();
  });
}
