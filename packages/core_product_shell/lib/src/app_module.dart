import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

import 'shell_id.dart';

/// A reusable module contract: a unit of product behavior (a feature, a
/// domain capability) that one or more shells can adopt.
///
/// Replaces the former `app/lib/core/features/feature_registry.dart`
/// `AppFeatureModule`, which lived inside the mobile super-app shell and so
/// could not be depended on by other shells (TV, Coins, or any future
/// modular app) without importing app-layer code. This contract lives in a
/// shared package instead, and is parameterized by [ShellId] — a module
/// decides what it exposes *per shell*, not via an if/else on "mobile or
/// TV".
abstract class AppModule {
  /// Stable, unique identifier for this module (for example `'iptv'`).
  String get id;

  /// The set of shells this module is available on. Any number of shells
  /// may be listed — this is not limited to two.
  Set<ShellId> get supportedShells;

  /// Whether this module should be registered for [shell].
  bool isEnabledForShell(ShellId shell) => supportedShells.contains(shell);

  /// Routes this module contributes when running under [shell].
  ///
  /// A module may return different route bundles per shell (for example a
  /// compact mobile route vs. a TV-optimized route) while keeping route
  /// *identity* (names) stable across shells where the underlying screen is
  /// shared.
  List<RouteBase> routesFor(ShellId shell);

  /// Riverpod provider overrides this module contributes when running under
  /// [shell]. Defaults to none.
  List<Override> providerOverridesFor(ShellId shell) => const [];

  /// Called once when the module is registered and initialization runs.
  Future<void> initialize() async {}

  /// Called when the owning shell tears the module down.
  Future<void> dispose() async {}
}
