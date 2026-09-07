import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart';

/// Real sender transport is Android-only today — [GoogleCastCustomMessageChannel]
/// only has a native implementation on Android (see
/// docs/superpowers/specs/2026-09-07-cast-multiview-remote-control-spec.md).
/// iOS falls back to [UnavailableMultiviewCastSenderTransport] rather than a
/// transport whose native calls would throw `MissingPluginException`.
Override realCastMultiviewSenderOverride() {
  return multiviewCastSenderTransportProvider.overrideWith((ref) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const UnavailableMultiviewCastSenderTransport();
    }
    return GoogleCastMultiviewSenderTransport();
  });
}
