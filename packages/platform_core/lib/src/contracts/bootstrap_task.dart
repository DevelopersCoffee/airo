import '../bootstrap/bootstrap_context.dart';
import '../result/result.dart';

abstract interface class BootstrapTask {
  String id();
  Set<String> provides();
  Set<String> dependsOn();
  
  /// Determines if this task is optional (lazy). If false, it blocks startup.
  bool isLazy() => false;
  
  Future<Result<void>> initialize(BootstrapContext context);
}
