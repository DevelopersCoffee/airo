import 'package:platform_core/platform_core.dart';

class DownloadsBootstrapTask implements BootstrapTask {
  const DownloadsBootstrapTask();

  @override
  String id() => 'downloads';

  @override
  Set<String> provides() => {'downloads'};

  @override
  Set<String> dependsOn() => {'logging', 'events', 'settings', 'jobs', 'filesystem', 'storage'};

  @override
  bool isLazy() => false;

  @override
  Future<Result<void>> initialize(BootstrapContext context) async {
    try {
      return const Result.success(null);
    } catch (e) {
      return Result.fatalFailure(Exception('DownloadsBootstrapTask failed: $e'));
    }
  }
}
