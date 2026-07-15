/// Open-source bootstrap seam for the Airo pro overlay.
///
/// This package intentionally registers nothing. The private `airo-pro`
/// repository ships a same-named package that registers real [ProModule]s;
/// pro builds swap it in through `pubspec_overrides.yaml` (the same
/// mechanism as `packages/stubs`). The app calls [registerProModules]
/// unconditionally and stays agnostic about which variant is linked.
library;

import 'package:core_entitlements/core_entitlements.dart';

/// The entitlement policy for this build flavor.
///
/// Open-source builds run the launch promo (every pro feature enabled).
/// The pro overlay may replace this with a billing-backed implementation
/// when charging begins; call sites are unaffected.
Entitlements createEntitlements() => const LaunchPromoEntitlements();

/// Contributes pro modules to [registry]. No-op in the open-source build.
void registerProModules(ProModuleRegistry registry) {
  // Intentionally empty: the GA build ships no pro modules.
}
