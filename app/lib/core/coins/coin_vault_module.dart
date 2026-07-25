import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

/// The Airo Coin vault as a shell-registrable [AppModule].
///
/// Wraps `package:feature_coin` (the ADR-0010 package-first vault — never
/// the frozen legacy `app/lib/features/coins` tree) so any shell can adopt
/// it through the shared `core_product_shell` contract. The Airo Coins
/// shell (`main_coins.dart`) is its first registry-driven consumer; the
/// super-app still mounts the same screens through its existing
/// `app_router.dart` wiring, which stays untouched per the no-break rule.
///
/// [basePath] controls where the vault mounts. The module both mounts its
/// routes there and overrides `feature_coin`'s `vaultRoutePrefixProvider`
/// to match, so the vault's internal add/edit navigation follows the mount
/// point instead of a hardcoded host-app URL. The default stays the
/// super-app's historical `/money/vault`.
class CoinVaultModule extends AppModule {
  CoinVaultModule({this.basePath = '/money/vault'})
    : assert(basePath.startsWith('/'), 'basePath must be absolute');

  /// Absolute route prefix the vault mounts under for the owning shell.
  final String basePath;

  @override
  String get id => 'coin_vault';

  /// Phone/tablet-class shells only. TV is excluded to match
  /// `packages/feature_coin/module.yaml`'s ship policy (`tv: Never Ship`).
  @override
  Set<ShellId> get supportedShells => {ShellId.mobile, ShellId.coins};

  @override
  List<Override> providerOverridesFor(ShellId shell) => [
    vaultRoutePrefixProvider.overrideWithValue(basePath),
  ];

  @override
  List<RouteBase> routesFor(ShellId shell) => [
    GoRoute(
      path: basePath,
      builder: (context, state) => const VaultGateScreen(),
      routes: [
        GoRoute(
          path: 'add/:type',
          builder: (context, state) => VaultRecordFormScreen(
            recordType: VaultRecordType.values.byName(
              state.pathParameters['type']!,
            ),
          ),
        ),
        GoRoute(
          path: 'edit/:type/:key',
          builder: (context, state) => VaultRecordFormScreen(
            recordType: VaultRecordType.values.byName(
              state.pathParameters['type']!,
            ),
            recordKey: state.pathParameters['key'],
          ),
        ),
      ],
    ),
  ];
}
