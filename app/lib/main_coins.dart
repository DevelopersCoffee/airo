/// Entrypoint for the Airo Coins shell.
///
/// The standalone Airo Coins app opens on a lean, content-first money summary
/// ([CoinsStandaloneHome]: recent transactions plus a Secure Vault entry)
/// rather than dropping straight onto the vault gate, so it feels like the
/// super-app's Coins tab instead of a biometric wall.
///
/// It registers [CoinVaultModule] — the ADR-0010 package-first vault from
/// `package:feature_coin` — scoped to [ShellId.coins], mounted at
/// `/money/vault` to match the super-app's vault path.
///
/// ADR-0010 exception (interim debt): the home reuses the legacy
/// `app/lib/features/coins` read path (recent transactions + display card),
/// which ADR-0010 otherwise keeps as a migration source only. The heavy
/// add/split/group/budget flows stay out of the standalone until the money
/// dashboard is migrated package-first into `feature_coin` (Airo Coin phased
/// epic #938–#942). See ADR-0010's "Standalone shell interim exception" note.
/// The read path self-wires from `appDatabaseProvider` (Drift, native), so no
/// extra bootstrap is required here.
///
/// Build command (no dedicated store build target yet):
/// ```bash
/// flutter build apk --release \
///   --target=lib/main_coins.dart \
///   --dart-define=APP_VARIANT=coins
/// ```
library;

import 'dart:async';

import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/coins/coins_standalone_home.dart';
import 'core/pro/pro_bootstrap_runner.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AiroCoinsApp(registry: buildCoinsModuleRegistry()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(runProBootstrap());
  });
}

/// Builds the Airo Coins shell's module registry. Split out (and returning
/// a fresh instance per call) so tests can exercise the exact registration
/// this entrypoint performs without sharing static state.
@visibleForTesting
ModuleRegistry buildCoinsModuleRegistry() {
  final registry = ModuleRegistry(shell: ShellId.coins)
    // Mount the vault at /money/vault so the dashboard's
    // RouteNames.coinVaultPath ('/money/vault') "Secure Vault" link resolves,
    // mirroring the super-app. The module overrides feature_coin's
    // vaultRoutePrefixProvider to match.
    ..register(CoinVaultModule(basePath: '/money/vault'));
  return registry;
}

/// Root widget for the Airo Coins shell: opens on the money dashboard, with
/// the vault reachable from it. Vault routes come from the module registry.
class AiroCoinsApp extends StatefulWidget {
  const AiroCoinsApp({super.key, required this.registry});

  final ModuleRegistry registry;

  @override
  State<AiroCoinsApp> createState() => _AiroCoinsAppState();
}

class _AiroCoinsAppState extends State<AiroCoinsApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const CoinsStandaloneHome(),
      ),
      ...widget.registry.allRoutes,
    ],
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
