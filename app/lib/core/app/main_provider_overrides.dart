import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/iptv/iptv_cast_provider_override.dart';
import '../providers/navigation_provider.dart';

/// Shell-owned provider overrides, plus whatever the composed modules bring.
///
/// Anything a module needs belongs in that module's `providerOverridesFor`
/// (see [ModuleRegistry.allProviderOverrides]) rather than here, so a shell
/// can never mount a module's routes while forgetting its providers.
///
/// [moduleRegistry] is required for exactly that reason: an optional registry
/// would let a caller build a scope that mounts module routes with none of the
/// providers behind them.
List<Override> buildMainProviderOverrides({
  required SharedPreferences prefs,
  required EpgReminderNotificationGateway epgReminderGateway,
  required ModuleRegistry moduleRegistry,
}) {
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    epgReminderNotificationGatewayProvider.overrideWithValue(
      epgReminderGateway,
    ),
    realIptvCastControllerOverride(),
    // Navigation chrome follows composition. R05 composes Mind out of
    // shared-surface builds (web), and the router then mounts a placeholder in
    // that branch — showing the Assistant destination anyway would advertise a
    // journey this binary does not carry. Keyed on the registry rather than on
    // a platform check so the two can never disagree.
    if (!moduleRegistry.isRegistered('mind'))
      appNavigationPolicyProvider.overrideWithValue(
        appNavigationPolicy.without(AppNavigationTab.assistant),
      ),
    ...moduleRegistry.allProviderOverrides,
  ];
}
