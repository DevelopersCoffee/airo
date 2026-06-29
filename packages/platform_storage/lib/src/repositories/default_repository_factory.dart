import '../contracts/repository_factory.dart';

class DefaultRepositoryFactory implements RepositoryFactory {
  final Map<Type, dynamic Function()> _builders = {};
  final Map<Type, dynamic> _instances = {};

  @override
  void register<T>(T Function() builder) {
    if (_builders.containsKey(T)) {
      throw StateError('Repository $T is already registered.');
    }
    _builders[T] = builder;
  }

  @override
  T get<T>() {
    if (_instances.containsKey(T)) {
      return _instances[T] as T;
    }
    final builder = _builders[T];
    if (builder == null) {
      throw StateError('Repository $T not found. Ensure it was registered during bootstrap.');
    }
    final instance = builder();
    _instances[T] = instance;
    return instance as T;
  }
}
