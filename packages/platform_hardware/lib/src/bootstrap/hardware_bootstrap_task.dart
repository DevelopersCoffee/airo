import 'package:platform_core/platform_core.dart';
import 'package:platform_events/platform_events.dart';
import 'package:platform_hardware/src/events/hardware_events.dart';
import 'package:platform_hardware/src/providers/hardware_service.dart';

class HardwareBootstrapTask implements BootstrapTask {

  const HardwareBootstrapTask({
    required this.service,
    required this.eventBus,
  });
  final HardwareService service;
  final EventBus eventBus;

  @override
  String id() => 'hardware';

  @override
  Set<String> provides() => {'hardware_profile'};

  @override
  Set<String> dependsOn() => {'logging', 'events', 'settings'};

  @override
  bool isLazy() => false;

  @override
  Future<Result<void>> initialize(BootstrapContext context) async {
    try {
      await service.initialize();
      final profile = service.profile;
      
      eventBus.publish(HardwareDetectedEvent(profile));
      return const Result.success(null);
    } catch (e) {
      return Result.fatalFailure(Exception('HardwareBootstrapTask failed: $e'));
    }
  }
}
