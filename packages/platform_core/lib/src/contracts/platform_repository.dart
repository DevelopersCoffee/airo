abstract interface class PlatformTransaction {
  Future<void> commit();
  Future<void> rollback();
}

abstract interface class PlatformRepository {
  Future<PlatformTransaction> beginTransaction();
}
