abstract interface class DatabaseBackupProvider {
  Future<String> createSnapshot();
  Future<void> restoreSnapshot(String path);
}
