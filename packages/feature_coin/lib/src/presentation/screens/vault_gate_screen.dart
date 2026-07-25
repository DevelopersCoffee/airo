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
    this.autoUnlock = false,
  });

  final Widget? unlockedChild;

  /// Whether to prompt for biometrics as soon as the vault opens.
  ///
  /// Defaults to false: the vault is browsable while locked (summaries are
  /// plaintext and need no key), and biometrics are requested at the point
  /// a sensitive value is actually read. Set true only where an immediate
  /// prompt is genuinely wanted.
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
    // Locked and auth-error states still render the vault: summaries are
    // plaintext columns that need no key, and every sensitive read goes
    // through VaultSessionNotifier.withKey, which fails closed while
    // locked. Biometrics are demanded when a record is opened or a field
    // revealed — not as a wall in front of the whole feature.
    final child = switch (state) {
      VaultUnlocked() => widget.unlockedChild ?? const VaultHomeScreen(),
      VaultUnlocking() => const _VaultUnlockingView(),
      VaultUnavailable() => const _VaultUnavailableView(),
      VaultAuthError(:final failure) => _LockedBrowseView(
        unlockedChild: widget.unlockedChild,
        message: failure.message,
      ),
      VaultLocked() => _LockedBrowseView(unlockedChild: widget.unlockedChild),
    };

    return VaultLifecycleObserver(child: child);
  }
}

/// The vault while locked: records are browsable by their non-sensitive
/// summaries, with a banner explaining that opening a record prompts for
/// biometrics. [message] carries a prior auth failure, when there was one.
class _LockedBrowseView extends ConsumerWidget {
  const _LockedBrowseView({this.unlockedChild, this.message});

  final Widget? unlockedChild;
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final failure = message;

    return Column(
      children: [
        Material(
          color: failure == null
              ? scheme.surfaceContainerHighest
              : scheme.errorContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Icon(
                    failure == null
                        ? Icons.lock_outline
                        : Icons.lock_reset_outlined,
                    size: 20,
                    color: failure == null ? null : scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      failure ??
                          'Locked. Details unlock with biometrics when you '
                              'open a record.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: failure == null ? null : scheme.onErrorContainer,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('vault_unlock_button'),
                    onPressed: () =>
                        ref.read(vaultSessionProvider.notifier).unlock(),
                    icon: const Icon(Icons.fingerprint, size: 18),
                    label: const Text('Unlock'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: unlockedChild ?? const VaultHomeScreen()),
      ],
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

class _VaultTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const _VaultTitleBar();

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('Secure Vault'));

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
