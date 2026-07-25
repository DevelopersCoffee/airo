import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_coin/feature_coin.dart';
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
/// Routes are mounted under `/money/vault` on every shell because
/// `feature_coin`'s screens navigate with those literal paths today
/// (`vault_home_screen.dart`, `record_detail_sheet.dart`). Making that
/// base path shell-configurable is a `feature_coin` API change tracked for
/// a later slice — not silently forked here.
class CoinVaultModule extends AppModule {
  @override
  String get id => 'coin_vault';

  /// Phone/tablet-class shells only. TV is excluded to match
  /// `packages/feature_coin/module.yaml`'s ship policy (`tv: Never Ship`).
  @override
  Set<ShellId> get supportedShells => {ShellId.mobile, ShellId.coins};

  @override
  List<RouteBase> routesFor(ShellId shell) => [
    GoRoute(
      path: '/money/vault',
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
