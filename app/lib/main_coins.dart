/// Entrypoint for the standalone Airo Coin phone app.
///
/// Mirrors the Aika Stream / Airo TV pattern: a dedicated Dart entrypoint
/// (`main_coins.dart`) paired with [`pubspec_coins.yaml`] and the Android
/// `coins` product flavor (`CoinsActivity`, `io.airo.app.coins`). Swap the
/// pubspec before building, same as TV:
/// ```bash
/// cp pubspec_coins.yaml pubspec.yaml && flutter pub get
/// ```
///
/// Build command:
/// ```bash
/// bash scripts/build-coins.sh
/// ```
/// or manually:
/// ```bash
/// flutter build apk --release \
///   --target=lib/main_coins.dart \
///   --dart-define=APP_VARIANT=coins
/// ```
library;

import 'package:airo_pro_bootstrap/airo_pro_bootstrap.dart' as pro_bootstrap;
import 'package:core_app_shell/core_app_shell.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/coins/coins_standalone_home.dart';
import 'core/coins/coins_standalone_identity.dart';
import 'core/pro/pro_bootstrap_runner.dart';
import 'features/coins/application/providers/coins_identity_provider.dart';
import 'core/coins/coins_standalone_groups_list_screen.dart';
import 'features/coins/presentation/screens/group_detail_screen.dart';

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
      await SharedPreferences.getInstance();
      await pro_bootstrap.prepareProEntitlements();
      registry = buildCoinsModuleRegistry();
      return AiroCoinsApp(registry: registry);
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

/// Builds the Airo Coin shell's module registry. Split out (and returning
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

/// Root widget for the Airo Coin shell: hub home with shared expenses and
/// vault routes from the module registry.
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
      GoRoute(
        path: '/groups',
        builder: (context, state) => const CoinsStandaloneGroupsListScreen(),
      ),
      GoRoute(
        path: '/groups/:groupId',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          return GroupDetailScreen(groupId: groupId);
        },
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
        coinsIdentityProvider.overrideWithValue(const LocalCoinsIdentity()),
      ],
      child: MaterialApp.router(
        title: 'Airo Coin',
        theme: AiroTheme.defaultDark,
        routerConfig: _router,
        builder: (context, child) => AiroDisplayScale(
          child: AiroDomainTheme(
            domain: AiroDomain.money,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
