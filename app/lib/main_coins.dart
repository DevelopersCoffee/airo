/// Entrypoint stub for the Airo Coins shell.
///
/// Phase 1 of the SSOT migration (ADR-0011,
/// `docs/adr/0011-super-app-modular-shell-ssot.md`) only requires that the
/// shared shell contract in `package:core_product_shell` accept a third
/// shell identifier as data, not that Airo Coins ship real UI or features.
/// This entrypoint proves exactly that: it boots a `ModuleRegistry` scoped to
/// `ShellId.coins` with zero modules registered, and renders a placeholder
/// screen. No real Airo Coin UI, routes, or business logic exist here.
///
/// Per ADR-0010 (`docs/adr/0010-airo-coin-package-first-development.md`),
/// the existing `app/lib/features/coins` tree is legacy, divergent
/// super-app finance code — a migration *source*, never a target for new
/// behavior. This entrypoint intentionally does not import it. Real Airo
/// Coins behavior belongs in a future package-first extraction
/// (`packages/feature_coin`-style), consumed here the same way
/// `main_tv.dart` consumes `packages/feature_iptv` — not by forking the
/// legacy screens.
///
/// Build command (once a real build target exists):
/// ```bash
/// flutter build apk --release \
///   --target=lib/main_coins.dart \
///   --dart-define=APP_VARIANT=coins
/// ```
library;

import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/material.dart';

/// The Airo Coins shell's module registry. Empty today — this only proves
/// the shared contract accepts a shell identifier beyond mobile/TV.
final ShellId coinsShellId = ShellId.coins;

final ModuleRegistry coinsModuleRegistry = ModuleRegistry(shell: ShellId.coins);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AiroCoinsStubApp());
}

/// Placeholder root widget for the Airo Coins shell. Replace with a real
/// app shell (routes, providers, theme) once Airo Coins features are
/// extracted package-first, per ADR-0010.
class AiroCoinsStubApp extends StatelessWidget {
  const AiroCoinsStubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Airo Coins — coming soon', key: Key('airo-coins-stub')),
        ),
      ),
    );
  }
}
