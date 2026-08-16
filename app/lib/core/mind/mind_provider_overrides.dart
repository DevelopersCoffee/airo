import 'package:airo_pro_bootstrap/airo_pro_bootstrap.dart' as pro_bootstrap;
import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider overrides the standalone Mind shell needs beyond what
/// [ModuleRegistry.allProviderOverrides] contributes.
///
/// The super app wires [sharedPreferencesProvider] through
/// [buildMainProviderOverrides]; Mind uses the same app-layer model manager
/// screens and must supply the same prefs seam or downloads, routing prefs,
/// and assistant model selection fail silently on first read.
List<Override> buildMindProviderOverrides({
  required SharedPreferences prefs,
  required ModuleRegistry registry,
}) {
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    mindEntitlementsProvider.overrideWithValue(
      pro_bootstrap.createEntitlements(),
    ),
    ...registry.allProviderOverrides,
  ];
}
