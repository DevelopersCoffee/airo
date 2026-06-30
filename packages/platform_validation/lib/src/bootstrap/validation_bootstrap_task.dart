import 'package:platform_core/platform_core.dart';

class ValidationBootstrapTask implements BootstrapTask {
  const ValidationBootstrapTask();

  @override
  String id() => 'validation';

  @override
  Set<String> provides() => {'validation'};

  @override
  Set<String> dependsOn() => {'logging', 'events', 'settings', 'downloads', 'hardware'};

  @override
  bool isLazy() => false;

  @override
  Future<Result<void>> initialize(BootstrapContext context) async {
    try {
      return const Result.success(null);
    } catch (e) {
      return Result.fatalFailure(Exception('ValidationBootstrapTask failed: $e'));
    }
  }
}
