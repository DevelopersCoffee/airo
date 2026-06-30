import 'package:platform_core/platform_core.dart';
import '../contracts/filesystem_service.dart';

class FilesystemBootstrapTask implements BootstrapTask {
  final FilesystemService _filesystemService;

  FilesystemBootstrapTask(this._filesystemService);

  @override
  String id() => 'filesystem';

  @override
  Set<String> provides() => {'filesystem'};

  @override
  Set<String> dependsOn() => {'storage', 'logging'};

  @override
  bool isLazy() => false;

  @override
  Future<Result<void>> initialize(BootstrapContext context) async {
    try {
      await _filesystemService.initialize();
      return const Success(null);
    } catch (e) {
      return FatalFailure(Exception(e.toString()));
    }
  }
}
