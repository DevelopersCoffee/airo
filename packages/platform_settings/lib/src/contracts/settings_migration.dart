abstract interface class SettingsMigration {
  int get fromVersion;
  int get toVersion;
  Future<void> execute();
}
