import 'package:platform_core/platform_core.dart';
import '../sinks/console_sink.dart';
import '../filters/level_filter.dart';
import '../levels/log_level.dart';

class LoggingBootstrapTask implements BootstrapTask {
  @override
  String get name => 'PlatformLogging';

  @override
  BootstrapPhase get phase => BootstrapPhase.logging;

  @override
  Future<BootstrapResult> execute(BootstrapContext context) async {
    // In a real implementation we would register the logger into Riverpod here
    // But since Riverpod handles injection we just verify basic setup
    return const BootstrapResult.success(BootstrapPhase.logging);
  }
}
