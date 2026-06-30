import 'package:platform_engine_sdk/platform_engine_sdk.dart';

abstract interface class RuntimeRegistry {
  void register(EngineProvider provider);
  void unregister(String identifier);
  List<EngineProvider> get providers;
  EngineProvider? getProvider(String identifier);
}
