import 'package:flutter_test/flutter_test.dart';
import 'package:platform_settings/platform_settings.dart';
import 'package:platform_events/platform_events.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_settings/src/registry/default_settings_registry.dart';
import 'package:platform_settings/src/api/memory_settings_service.dart';

void main() {
  group('SettingsRegistry', () {
    test('Allows registration and retrieves correctly', () {
      final registry = DefaultSettingsRegistry();
      final setting = ThemeSetting();
      
      registry.register(setting);
      
      final retrieved = registry.getSetting<String>('platform.theme');
      expect(retrieved, isNotNull);
      expect(retrieved?.key, 'theme');
    });

    test('Prevents duplicate registration', () {
      final registry = DefaultSettingsRegistry();
      final setting = ThemeSetting();
      
      registry.register(setting);
      expect(() => registry.register(setting), throwsArgumentError);
    });

    test('Prevents registration after locking', () {
      final registry = DefaultSettingsRegistry();
      registry.lock();
      
      expect(() => registry.register(ThemeSetting()), throwsStateError);
    });
  });

  group('MemorySettingsService', () {
    test('Returns default value when not set', () {
      final registry = DefaultSettingsRegistry();
      final setting = ThemeSetting();
      registry.register(setting);
      
      final service = MemorySettingsService(registry);
      
      expect(service.getValue(setting), 'system');
    });

    test('Validates before setting value', () async {
      final registry = DefaultSettingsRegistry();
      final setting = ThemeSetting();
      registry.register(setting);
      
      final service = MemorySettingsService(registry);
      
      await expectLater(
        service.setValue(setting, 'invalid_theme'), 
        throwsArgumentError
      );
      
      // Value should remain unchanged
      expect(service.getValue(setting), 'system');
      
      await service.setValue(setting, 'dark');
      expect(service.getValue(setting), 'dark');
    });
  });

  group('Event Integration', () {
    test('Dispatches SettingsChangedEvent when setting changes', () async {
      final container = ProviderContainer();
      
      final registry = container.read(settingsRegistryProvider);
      final setting = ThemeSetting();
      registry.register(setting);
      
      final eventBus = container.read(eventBusProvider);
      final service = container.read(settingsServiceProvider);
      
      SettingsChangedEvent<String>? capturedEvent;
      eventBus.subscribe<SettingsChangedEvent<String>>((event) async {
        capturedEvent = event;
      });

      await service.setValue(setting, 'light');
      
      // Flush microtasks
      await Future.delayed(Duration.zero);
      
      expect(capturedEvent, isNotNull);
      expect(capturedEvent?.oldValue, 'system');
      expect(capturedEvent?.newValue, 'light');
      expect(capturedEvent?.setting.identifier, 'platform.theme');
    });
  });
}
