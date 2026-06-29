import 'package:platform_core/platform_core.dart';
import '../contracts/storage_service.dart';

class StorageBootstrapTask implements BootstrapTask {
  final StorageService _storageService;

  StorageBootstrapTask(this._storageService);

  @override
  String get name => 'PlatformStorage';

  @override
  BootstrapPhase get phase => BootstrapPhase.storage;

  @override
  Future<BootstrapResult> execute(BootstrapContext context) async {
    try {
      await _storageService.initialize();
      return const BootstrapResult.success(BootstrapPhase.storage);
    } catch (e) {
      return BootstrapResult.failure(BootstrapPhase.storage, e.toString());
    }
  }
}
