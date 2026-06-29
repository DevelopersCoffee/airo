import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_events/platform_events.dart';
import '../contracts/settings_registry.dart';
import '../contracts/settings_service.dart';
import '../registry/default_settings_registry.dart';
import '../api/memory_settings_service.dart';
import '../observers/event_bus_settings_observer.dart';

final settingsRegistryProvider = Provider<SettingsRegistry>((ref) {
  return DefaultSettingsRegistry();
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  final registry = ref.watch(settingsRegistryProvider);
  final eventPublisher = ref.watch(eventPublisherProvider);
  
  return MemorySettingsService(
    registry,
    observers: [EventBusSettingsObserver(eventPublisher)],
  );
});
