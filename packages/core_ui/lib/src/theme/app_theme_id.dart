/// Stable identifiers for user-selectable Airo themes.
enum AppThemeId {
  cyber,
  classic,
  bedtime,
  airoTv;

  String get storageValue => name;

  static AppThemeId fromStorageValue(
    String? value, {
    AppThemeId fallback = AppThemeId.cyber,
  }) {
    return AppThemeId.values.firstWhere(
      (themeId) => themeId.storageValue == value,
      orElse: () => fallback,
    );
  }
}
