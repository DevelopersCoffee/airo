import 'package:platform_core/platform_core.dart';
import '../contracts/storage_service.dart';

class StorageBootstrapTask implements BootstrapTask {
  final StorageService _storageService;

  StorageBootstrapTask(this._storageService);

  @override
  String id() => 'storage';

  @override
  Set<String> provides() => {'storage'};

  @override
  Set<String> dependsOn() => {'logging', 'settings', 'events'};

  @override
  bool isLazy() => false;

  @override
  Future<Result<void>> initialize(BootstrapContext context) async {
    try {
      await _storageService.initialize();
      return const Success(null);
    } catch (e) {
      return FatalFailure(Exception(e.toString()));
    }
  }
}
