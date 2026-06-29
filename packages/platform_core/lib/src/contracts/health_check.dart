import '../result/result.dart';

abstract interface class HealthCheck {
  String get componentName;
  Future<Result<bool>> checkHealth();
}
