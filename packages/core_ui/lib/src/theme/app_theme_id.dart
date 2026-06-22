/// Stable identifiers for user-selectable Airo themes.
enum AppThemeId {
  cyber,
  classic,
  bedtime;

  String get storageValue => name;

  static AppThemeId fromStorageValue(String? value) {
    return AppThemeId.values.firstWhere(
      (themeId) => themeId.storageValue == value,
      orElse: () => AppThemeId.cyber,
    );
  }
}
