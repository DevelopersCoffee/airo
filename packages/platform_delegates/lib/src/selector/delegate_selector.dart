import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_hardware/platform_hardware.dart';

import '../session/delegate_session.dart';

abstract interface class DelegateSelector {
  DelegateSelection selectDelegate({
    required HardwareProfile hardwareProfile,
    required EngineCapabilities engineCapabilities,
    required dynamic modelDescriptor,
    required Map<String, dynamic> userPreferences,
  });
}
