/// Entrypoint for the Airo Coins shell.
///
/// Phase 2 of the SSOT migration: the stub proved the shared shell
/// contract (`package:core_product_shell`) accepts a third [ShellId]; this
/// entrypoint now consumes it for real. It registers [CoinVaultModule] —
/// the ADR-0010 package-first vault from `package:feature_coin` — with a
/// registry scoped to [ShellId.coins] and routes entirely from
/// `registry.allRoutes`, the same way `main_tv.dart` consumes
/// `packages/feature_iptv` rather than forking screens.
///
/// Per ADR-0010 (`docs/adr/0010-airo-coin-package-first-development.md`),
/// the legacy `app/lib/features/coins` tree stays a migration source only;
/// nothing here imports it.
///
/// Build command (no dedicated store build target yet):
/// ```bash
/// flutter build apk --release \
///   --target=lib/main_coins.dart \
///   --dart-define=APP_VARIANT=coins
/// ```
library;

import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/coins/coin_vault_module.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AiroCoinsApp(registry: buildCoinsModuleRegistry()));
}

/// Builds the Airo Coins shell's module registry. Split out (and returning
/// a fresh instance per call) so tests can exercise the exact registration
/// this entrypoint performs without sharing static state.
@visibleForTesting
ModuleRegistry buildCoinsModuleRegistry() {
  final registry = ModuleRegistry(shell: ShellId.coins)
    // Standalone shell owns its URL space: mount the vault at /vault
    // instead of inheriting the super-app's /money/vault prefix. The
    // module overrides feature_coin's vaultRoutePrefixProvider to match.
    ..register(CoinVaultModule(basePath: '/vault'));
  return registry;
}

/// Root widget for the Airo Coins shell: a vault-first app whose routes
/// come entirely from the module registry, not hand-wired screens.
class AiroCoinsApp extends StatefulWidget {
  const AiroCoinsApp({super.key, required this.registry});

  final ModuleRegistry registry;

  @override
  State<AiroCoinsApp> createState() => _AiroCoinsAppState();
}

class _AiroCoinsAppState extends State<AiroCoinsApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/vault',
    routes: widget.registry.allRoutes,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: widget.registry.allProviderOverrides,
      child: MaterialApp.router(
        title: 'Airo Coins',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFB8860B),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        routerConfig: _router,
      ),
    );
  }
}
