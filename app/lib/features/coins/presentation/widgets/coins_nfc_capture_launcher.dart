import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/services/coins_nfc_capture_platform.dart';
import '../../application/services/coins_nfc_capture_session.dart';

/// Polls the Android activity for a pending NFC / deep-link capture launch and
/// navigates to [captureRoute] when login preconditions pass.
class CoinsNfcCaptureLauncher extends ConsumerStatefulWidget {
  const CoinsNfcCaptureLauncher({
    super.key,
    required this.child,
    required this.captureRoute,
    this.requireSuperAppLogin = false,
  });

  final Widget child;
  final String captureRoute;
  final bool requireSuperAppLogin;

  @override
  ConsumerState<CoinsNfcCaptureLauncher> createState() =>
      _CoinsNfcCaptureLauncherState();
}

class _CoinsNfcCaptureLauncherState
    extends ConsumerState<CoinsNfcCaptureLauncher>
    with WidgetsBindingObserver {
  var _handlingPendingCapture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpenCapture());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeOpenCapture();
    }
  }

  Future<void> _maybeOpenCapture() async {
    if (!mounted || _handlingPendingCapture) return;

    final hasPending = await CoinsNfcCapturePlatform.hasPendingCaptureLaunch();
    if (!mounted || !hasPending) return;

    _handlingPendingCapture = true;
    try {
      if (widget.requireSuperAppLogin &&
          !await CoinsNfcCaptureSession.passesSuperAppLoginGate()) {
        return;
      }

      final consumed =
          await CoinsNfcCapturePlatform.consumePendingCaptureLaunch();
      if (!mounted || !consumed) return;

      context.go(widget.captureRoute);
    } finally {
      _handlingPendingCapture = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
