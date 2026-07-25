import 'package:airo_pro_bootstrap/airo_pro_bootstrap.dart' as pro_bootstrap;
import 'package:core_entitlements/core_entitlements.dart';
import 'package:flutter/foundation.dart';

/// Runs the open-core pro bootstrap seam for one shell.
///
/// Every entrypoint (super-app, TV, Coins) calls this once after first
/// frame. In open-source builds `registerProModules` is a no-op, so this
/// resolves to an empty list at near-zero cost; in `airo-pro` overlay
/// builds the same-named package registers real modules and
/// [ProModuleRegistry.initializeEntitled] starts the entitled subset.
///
/// Failures never propagate: the overlay contract is that a broken pro
/// module degrades to the open-source baseline, not a broken app.
///
/// [entitlements] and [register] exist for tests to stand in for the
/// build-flavor-linked seam; production callers pass neither.
Future<List<String>> runProBootstrap({
  void Function(String message)? log,
  Entitlements Function()? entitlements,
  void Function(ProModuleRegistry registry)? register,
}) async {
  final logger = log ?? debugPrint;
  try {
    final registry = ProModuleRegistry(
      (entitlements ?? pro_bootstrap.createEntitlements)(),
    );
    (register ?? pro_bootstrap.registerProModules)(registry);
    final initialized = await registry.initializeEntitled();
    if (initialized.isNotEmpty) {
      logger('✨ Pro modules initialized: ${initialized.join(', ')}');
    }
    return initialized;
  } catch (e) {
    logger('⚠️ Pro bootstrap failed; continuing with baseline: $e');
    return const [];
  }
}
