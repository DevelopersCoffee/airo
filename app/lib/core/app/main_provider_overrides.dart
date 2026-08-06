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
List<Override> buildMainProviderOverrides({
  required SharedPreferences prefs,
  required EpgReminderNotificationGateway epgReminderGateway,
  ModuleRegistry? moduleRegistry,
}) {
  final registry = moduleRegistry;
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    epgReminderNotificationGatewayProvider.overrideWithValue(
      epgReminderGateway,
    ),
    realIptvCastControllerOverride(),
    if (registry != null) ...registry.allProviderOverrides,
  ];
}
