import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../application/services/coins_nfc_capture_platform.dart';

/// Polls the Android activity for a pending NFC / deep-link capture launch and
/// navigates to [captureRoute].
class CoinsNfcCaptureLauncher extends StatefulWidget {
  const CoinsNfcCaptureLauncher({
    super.key,
    required this.child,
    required this.captureRoute,
  });

  final Widget child;
  final String captureRoute;

  @override
  State<CoinsNfcCaptureLauncher> createState() =>
      _CoinsNfcCaptureLauncherState();
}

class _CoinsNfcCaptureLauncherState extends State<CoinsNfcCaptureLauncher>
    with WidgetsBindingObserver {
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
    if (!mounted) return;
    final pending = await CoinsNfcCapturePlatform.consumePendingCaptureLaunch();
    if (!mounted || !pending) return;
    context.go(widget.captureRoute);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
