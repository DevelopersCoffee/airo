import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/screen_security.dart';
import '../../application/vault_session.dart';
import '../widgets/vault_lifecycle_observer.dart';
import 'vault_home_screen.dart';
import 'vault_lock_screen.dart';

/// Entry point for every vault route.
///
/// It switches on session state, prompts for biometrics on entry, keeps the
/// lifecycle observer mounted, and keeps screen protection active while the
/// vault route is visible.
class VaultGateScreen extends ConsumerStatefulWidget {
  const VaultGateScreen({super.key});

  @override
  ConsumerState<VaultGateScreen> createState() => _VaultGateScreenState();
}

class _VaultGateScreenState extends ConsumerState<VaultGateScreen> {
  @override
  void initState() {
    super.initState();
    ScreenSecurity.protect();
    Future.microtask(() => ref.read(vaultSessionProvider.notifier).unlock());
  }

  @override
  void dispose() {
    ScreenSecurity.unprotect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(vaultSessionProvider);
    final body = switch (session) {
      VaultUnlocked() => const VaultHomeScreen(),
      VaultUnavailable() => const VaultUnavailableView(),
      VaultAuthError(:final failure) => VaultAuthErrorView(failure: failure),
      _ => const VaultLockScreen(),
    };
    return VaultLifecycleObserver(child: body);
  }
}
