abstract class Bootstrap {
  Future<void> initialize();
}

abstract class Registry {
  void register(dynamic component);
}

abstract class Executor {
  Future<void> execute(dynamic plan);
}

abstract class ResourceManager {
  void allocate(dynamic resource);
}

abstract class EventBus {
  void publish(dynamic event);
}

abstract class ServiceLocator {
  T locate<T>();
}

abstract class PolicyEngine {
  dynamic resolvePolicies();
}

class PlatformKernel {
  PlatformKernel({
    required this.bootstrap,
    required this.registry,
    required this.executor,
    required this.resourceManager,
    required this.eventBus,
    required this.serviceLocator,
    required this.policyEngine,
  });

  final Bootstrap bootstrap;
  final Registry registry;
  final Executor executor;
  final ResourceManager resourceManager;
  final EventBus eventBus;
  final ServiceLocator serviceLocator;
  final PolicyEngine policyEngine;
}
