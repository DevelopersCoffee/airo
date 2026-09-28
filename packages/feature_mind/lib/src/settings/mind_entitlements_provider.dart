import 'package:core_entitlements/core_entitlements.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Entitlement policy for Mind surfaces that gate pro packs (Indic intelligence).
///
/// Play / open-source defaults deny pro packs. Shells override this with
/// [createEntitlements] from `airo_pro_bootstrap` at composition root so
/// overlay builds can enable packs after a license policy is linked.
final mindEntitlementsProvider = Provider<Entitlements>(
  (ref) => const NoEntitlements(),
);
