import '../services/service_locator.dart';

abstract interface class IsolationPolicy {
  bool checkCompatibility(List<Type> requiredServices, ServiceLocator locator);
}

class DefaultIsolationPolicy implements IsolationPolicy {
  @override
  bool checkCompatibility(List<Type> requiredServices, ServiceLocator locator) {
    for (final serviceType in requiredServices) {
      if (!locator.isRegisteredType(serviceType)) {
        return false;
      }
    }
    return true;
  }
}
