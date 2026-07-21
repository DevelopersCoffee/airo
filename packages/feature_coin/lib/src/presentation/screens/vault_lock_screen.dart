import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/vault_session.dart';

/// Shown whenever the vault is locked. The gate triggers one biometric prompt
/// automatically on entry; this screen is the manual retry surface.
class VaultLockScreen extends ConsumerWidget {
  const VaultLockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              'Vault locked',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock with biometrics'),
              onPressed: () => ref.read(vaultSessionProvider.notifier).unlock(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Device has no biometric/device-credential capability. Fail-closed per ADR
/// 0009: vault creation is never offered here.
class VaultUnavailableView extends StatelessWidget {
  const VaultUnavailableView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: EmptyStateWidget(
        icon: Icons.no_encryption_outlined,
        title: 'Biometrics required',
        message:
            'The Airo Coin vault needs a device lock (fingerprint, face, or '
            'screen lock). Set one up in system settings, then return here.',
      ),
    );
  }
}

/// Hard-stop auth failure surface: never a silent retry loop.
class VaultAuthErrorView extends ConsumerWidget {
  const VaultAuthErrorView({super.key, required this.failure});

  final BaseFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ErrorView(
        icon: Icons.error_outline,
        title: 'Could not unlock the vault',
        message: failure.message,
        retryLabel: 'Try again',
        onRetry: () => ref.read(vaultSessionProvider.notifier).unlock(),
      ),
    );
  }
}
