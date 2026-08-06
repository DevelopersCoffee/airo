import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/iptv/iptv_cast_provider_override.dart';

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
    ...moduleRegistry.allProviderOverrides,
  ];
}
