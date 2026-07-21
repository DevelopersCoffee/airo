import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/vault_session.dart';

/// Locks the vault whenever the app goes to background while [child] (the
/// vault route subtree) is mounted. Mounted once by `VaultGateScreen`.
class VaultLifecycleObserver extends ConsumerStatefulWidget {
  const VaultLifecycleObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VaultLifecycleObserver> createState() =>
      _VaultLifecycleObserverState();
}

class _VaultLifecycleObserverState extends ConsumerState<VaultLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(vaultSessionProvider.notifier).onAppBackground();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
