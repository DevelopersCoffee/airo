import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_assistant/feature_assistant.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/iptv/iptv_cast_provider_override.dart';
import '../assistant/app_assistant_host_adapter.dart';

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
    // The assistant package refuses to build without a host adapter.
    assistantHostAdapterProvider.overrideWith(
      (ref) => AppAssistantHostAdapter(ref),
    ),
    if (registry != null) ...registry.allProviderOverrides,
  ];
}
