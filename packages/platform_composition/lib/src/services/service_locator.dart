abstract interface class ServiceLocator {
  T resolve<T>();
  void register<T>(T instance);
  bool isRegistered<T>();
  bool isRegisteredType(Type type);
}

class DefaultServiceLocator implements ServiceLocator {
  final Map<Type, dynamic> _services = {};

  @override
  T resolve<T>() {
    if (!_services.containsKey(T)) {
      throw StateError('Service not found for type: $T');
    }
    return _services[T] as T;
  }

  @override
  void register<T>(T instance) {
    if (_services.containsKey(T)) {
      throw StateError('Service already registered for type: $T');
    }
    _services[T] = instance;
  }

  @override
  bool isRegistered<T>() => _services.containsKey(T);

  @override
  bool isRegisteredType(Type type) => _services.containsKey(type);
}
