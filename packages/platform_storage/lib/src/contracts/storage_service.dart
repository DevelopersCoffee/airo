import 'package:platform_core/platform_core.dart';
import 'database_health_checker.dart';

abstract interface class StorageService implements PlatformService {
  Future<void> initialize();
  Future<void> close();
  DatabaseHealthChecker get healthChecker;
}
