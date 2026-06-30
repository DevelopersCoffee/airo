abstract interface class NativeRuntime {
  Future<void> initialize();
  Future<void> dispose();
}
