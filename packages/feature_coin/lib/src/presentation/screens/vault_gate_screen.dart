import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/screen_security.dart';
import '../../application/vault_session.dart';
import '../widgets/vault_lifecycle_observer.dart';
import 'vault_home_screen.dart';

class VaultGateScreen extends ConsumerStatefulWidget {
  const VaultGateScreen({
    super.key,
    this.unlockedChild,
    this.autoUnlock = true,
  });

  final Widget? unlockedChild;
  final bool autoUnlock;

  @override
  ConsumerState<VaultGateScreen> createState() => _VaultGateScreenState();
}

class _VaultGateScreenState extends ConsumerState<VaultGateScreen> {
  late final VaultScreenSecurity _screenSecurity;
  var _autoUnlockAttempted = false;

  @override
  void initState() {
    super.initState();
    _screenSecurity = ref.read(screenSecurityProvider);
    Future<void>.microtask(_screenSecurity.protect);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoUnlock());
  }

  @override
  void dispose() {
    Future<void>.microtask(_screenSecurity.unprotect);
    super.dispose();
  }

  void _maybeAutoUnlock() {
    if (!mounted || !widget.autoUnlock || _autoUnlockAttempted) return;
    if (ref.read(vaultSessionProvider) is! VaultLocked) return;
    _autoUnlockAttempted = true;
    ref.read(vaultSessionProvider.notifier).unlock();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultSessionProvider);
    final child = switch (state) {
      VaultUnlocked() => widget.unlockedChild ?? const VaultHomeScreen(),
      VaultUnlocking() => const _VaultUnlockingView(),
      VaultUnavailable() => const _VaultUnavailableView(),
      VaultAuthError(:final failure) => _VaultAuthErrorView(
        message: failure.message,
      ),
      VaultLocked() => const _VaultLockedView(),
    };

    return VaultLifecycleObserver(child: child);
  }
}

class _VaultLockedView extends ConsumerWidget {
  const _VaultLockedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Vault')),
      body: EmptyStateWidget(
        icon: Icons.lock_outline,
        title: 'Vault locked',
        message:
            'Unlock with your device biometrics to view local vault records.',
        action: FilledButton.icon(
          key: const ValueKey('vault_unlock_button'),
          onPressed: () => ref.read(vaultSessionProvider.notifier).unlock(),
          icon: const Icon(Icons.fingerprint),
          label: const Text('Unlock vault'),
        ),
      ),
    );
  }
}

class _VaultUnlockingView extends StatelessWidget {
  const _VaultUnlockingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: _VaultTitleBar(),
      body: Center(child: LoadingIndicator(message: 'Unlocking vault')),
    );
  }
}

class _VaultUnavailableView extends StatelessWidget {
  const _VaultUnavailableView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: _VaultTitleBar(),
      body: EmptyStateWidget(
        icon: Icons.no_encryption_outlined,
        title: 'Biometrics unavailable',
        message:
            'Enroll biometrics or a supported device credential in system settings before creating an Airo Coin vault.',
      ),
    );
  }
}

class _VaultAuthErrorView extends ConsumerWidget {
  const _VaultAuthErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const _VaultTitleBar(),
      body: ErrorView(
        icon: Icons.lock_reset_outlined,
        title: 'Could not unlock vault',
        message: message,
        retryLabel: 'Try again',
        onRetry: () => ref.read(vaultSessionProvider.notifier).unlock(),
      ),
    );
  }
}

class _VaultTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const _VaultTitleBar();

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('Secure Vault'));

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
