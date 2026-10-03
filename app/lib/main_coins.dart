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

import 'package:airo_pro_bootstrap/airo_pro_bootstrap.dart' as pro_bootstrap;
import 'package:core_app_shell/core_app_shell.dart';
import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/coins/coins_standalone_home.dart';
import 'features/coins/application/providers/coins_currency_provider.dart';
import 'features/coins/presentation/screens/coins_settings_screen.dart';
import 'features/coins/presentation/screens/nfc_quick_expense_capture_screen.dart';
import 'features/coins/presentation/widgets/coins_nfc_capture_launcher.dart';
import 'core/pro/pro_bootstrap_runner.dart';

/// Standalone coins quick-capture route (mirrors [RouteNames.coinsStandaloneQuickCapturePath]
/// in the super-app router without importing the mind-backed route table).
const String _coinsStandaloneQuickCapturePath = '/quick-capture';

void main() {
  late ModuleRegistry registry;

  AiroBootstrap.run(
    shell: ShellId.coins,
    // `pubspec_coins.yaml` carries no `firebase_core` — the standalone
    // vault has no auth surface that needs it — and no `image_picker` /
    // `package_info_plus` / `url_launcher` / `core_data`, the dependencies
    // `GlobalErrorHandler` needs for its bug-report dialog. Wiring either in
    // for this shell alone would be a dependency-footprint change beyond
    // #1680's scope, so both are explicit, documented opt-outs rather than
    // silent gaps.
    errorHandler: ErrorHandlerPolicy.disabled(
      reason:
          'lean standalone shell; GlobalErrorHandler needs image_picker/'
          'package_info_plus/url_launcher/core_data, none of which '
          'pubspec_coins.yaml carries today (#1680)',
    ),
    firebase: FirebasePolicy.skip(
      reason:
          'pubspec_coins.yaml carries no firebase_core dependency; '
          'the standalone vault has no auth surface today',
    ),
    composeApp: () async {
      final prefs = await SharedPreferences.getInstance();
      await pro_bootstrap.prepareProEntitlements();
      registry = buildCoinsModuleRegistry();
      return AiroCoinsApp(registry: registry, prefs: prefs);
    },
    afterRunApp: () {
      scheduleDeferredStartupTask(
        debugName: 'coins_feature_initialization',
        task: registry.initializeAll,
      );
      scheduleDeferredProBootstrap();
    },
  );
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
  const AiroCoinsApp({super.key, required this.registry, required this.prefs});

  final ModuleRegistry registry;
  final SharedPreferences prefs;

  @override
  State<AiroCoinsApp> createState() => _AiroCoinsAppState();
}

class _AiroCoinsAppState extends State<AiroCoinsApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (NfcExpenseCaptureLink.matches(state.uri)) {
        return _coinsStandaloneQuickCapturePath;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const CoinsStandaloneHome(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const CoinsSettingsScreen(),
      ),
      GoRoute(
        path: _coinsStandaloneQuickCapturePath,
        builder: (context, state) => const NfcQuickExpenseCaptureScreen(),
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
      overrides: [
        ...widget.registry.allProviderOverrides,
        coinsCurrencyProvider.overrideWith(
          (ref) => CoinsCurrencyNotifier(widget.prefs),
        ),
      ],
      child: MaterialApp.router(
        title: 'Airo Coins',
        theme: AiroTheme.defaultDark,
        routerConfig: _router,
        builder: (context, child) => CoinsNfcCaptureLauncher(
          captureRoute: _coinsStandaloneQuickCapturePath,
          requireSuperAppLogin: false,
          child: AiroDisplayScale(
            child: AiroDomainTheme(
              domain: AiroDomain.money,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
