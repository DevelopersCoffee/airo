abstract interface class DatabaseMigration {
  int get fromVersion;
  int get toVersion;
  Future<void> execute();
}
