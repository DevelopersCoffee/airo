import 'platform_service.dart';

abstract interface class FeatureModule implements PlatformService {
  void registerDependencies();
  void registerRoutes();
}
