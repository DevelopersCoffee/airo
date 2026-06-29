import 'package:platform_core/platform_core.dart';
import '../contracts/filesystem_service.dart';

class FilesystemBootstrapTask implements BootstrapTask {
  final FilesystemService _filesystemService;

  FilesystemBootstrapTask(this._filesystemService);

  @override
  String get name => 'PlatformFilesystem';

  @override
  BootstrapPhase get phase => BootstrapPhase.storage; // Runs in storage phase but logically separate

  @override
  Future<BootstrapResult> execute(BootstrapContext context) async {
    try {
      await _filesystemService.initialize();
      return const BootstrapResult.success(BootstrapPhase.storage);
    } catch (e) {
      return BootstrapResult.failure(BootstrapPhase.storage, e.toString());
    }
  }
}
