import 'package:platform_core/platform_core.dart';
import '../sinks/console_sink.dart';
import '../filters/level_filter.dart';
import '../levels/log_level.dart';

class LoggingBootstrapTask implements BootstrapTask {
  @override
  String id() => 'logging';

  @override
  Set<String> provides() => {'logging'};

  @override
  Set<String> dependsOn() => {'environment'};

  @override
  bool isLazy() => false;

  @override
  Future<Result<void>> initialize(BootstrapContext context) async {
    return const Success(null);
  }
}
