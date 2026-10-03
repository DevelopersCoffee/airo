import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/services/coins_nfc_capture_platform.dart';

/// Polls the Android activity for a pending NFC / deep-link capture launch and
/// navigates to [captureRoute] when [canOpenQuickCapture] allows it.
class CoinsNfcCaptureLauncher extends ConsumerStatefulWidget {
  const CoinsNfcCaptureLauncher({
    super.key,
    required this.child,
    required this.captureRoute,
    required this.canOpenQuickCapture,
  });

  final Widget child;
  final String captureRoute;
  final Future<bool> Function(WidgetRef ref) canOpenQuickCapture;

  @override
  ConsumerState<CoinsNfcCaptureLauncher> createState() =>
      _CoinsNfcCaptureLauncherState();
}

class _CoinsNfcCaptureLauncherState extends ConsumerState<CoinsNfcCaptureLauncher>
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
    if (!await widget.canOpenQuickCapture(ref)) return;
    final pending = await CoinsNfcCapturePlatform.consumePendingCaptureLaunch();
    if (!mounted || !pending) return;
    if (!await widget.canOpenQuickCapture(ref)) return;
    context.go(widget.captureRoute);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
