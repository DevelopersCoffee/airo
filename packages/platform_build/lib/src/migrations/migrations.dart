abstract interface class PlatformMigration {
  String get fromVersion;
  String get toVersion;
  Future<bool> migrate(String projectPath);
}
