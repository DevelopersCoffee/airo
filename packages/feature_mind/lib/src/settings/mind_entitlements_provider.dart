import 'package:core_entitlements/core_entitlements.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Entitlement policy for Mind surfaces that gate pro packs (Indic intelligence).
///
/// Defaults to the launch promo in open-source builds. Shells may override
/// with [createEntitlements] from `airo_pro_bootstrap` at composition root.
final mindEntitlementsProvider = Provider<Entitlements>(
  (ref) => const LaunchPromoEntitlements(),
);
