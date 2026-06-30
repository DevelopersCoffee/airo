import 'package:platform_core/platform_core.dart';

class RuntimeBootstrapTask implements BootstrapTask {
  const RuntimeBootstrapTask();

  @override
  String id() => 'runtime';

  @override
  Set<String> provides() => {'runtime'};

  @override
  Set<String> dependsOn() => {'logging', 'events', 'settings', 'hardware', 'validation'};

  @override
  bool isLazy() => false;

  @override
  Future<Result<void>> initialize(BootstrapContext context) async {
    try {
      return const Result.success(null);
    } catch (e) {
      return Result.fatalFailure(Exception('RuntimeBootstrapTask failed: $e'));
    }
  }
}
