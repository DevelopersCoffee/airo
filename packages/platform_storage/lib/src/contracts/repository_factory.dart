abstract interface class RepositoryFactory {
  void register<T>(T Function() builder);
  T get<T>();
}
