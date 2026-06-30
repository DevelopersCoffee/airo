import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_core/platform_core.dart';
import 'package:platform_logging/platform_logging.dart';
import 'package:platform_storage/platform_storage.dart';
import 'package:platform_filesystem/platform_filesystem.dart';
import 'package:platform_jobs/platform_jobs.dart';
import 'package:platform_models/platform_models.dart';
import 'package:platform_hardware/platform_hardware.dart';
import 'package:platform_downloads/platform_downloads.dart';
import 'package:platform_validation/platform_validation.dart';
import 'package:platform_runtime/platform_runtime.dart';
import 'package:platform_events/platform_events.dart';

class AppBootstrap {
  final ProviderContainer _container;

  AppBootstrap(this._container);

  Future<void> execute() async {
    final registry = BootstrapRegistry();
    
    // Register platform tasks
    registry.register(LoggingBootstrapTask());
    registry.register(StorageBootstrapTask(_container.read(storageServiceProvider)));
    registry.register(FilesystemBootstrapTask(_container.read(filesystemServiceProvider)));
    registry.register(JobsBootstrapTask(_container.read(jobSchedulerProvider)));
    registry.register(ModelsBootstrapTask(catalog: _container.read(modelCatalogProvider)));
    registry.register(HardwareBootstrapTask(
      service: _container.read(hardwareServiceProvider),
      eventBus: _container.read(eventBusProvider),
    ));
    registry.register(const DownloadsBootstrapTask());
    registry.register(const ValidationBootstrapTask());
    registry.register(const RuntimeBootstrapTask());

    // Execute coordinator
    final coordinator = _container.read(bootstrapCoordinatorProvider.notifier);
    
    try {
      await coordinator.execute(_container);
      
      // Dispatch ready event if we had an event publisher injected here.
      // The coordinator handles basic state transitions natively.
    } catch (e) {
      // Bootstrap failed. The AppShell will render the ErrorScreen based on LifecycleState.
    }
  }
}
