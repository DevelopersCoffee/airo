/// Application configuration based on build environment.
///
/// Configuration is loaded from environment variables at build time.
/// Use `--dart-define` to set values:
/// ```
/// flutter run --dart-define=ENV=dev --dart-define=DEMO_MODE=true
/// ```
class AppConfig {
  AppConfig._();

  /// Current environment (dev, staging, prod)
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'dev',
  );

  /// Whether demo mode is enabled (shows demo credentials UI)
  static const bool isDemoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: true,
  );

  /// Whether to enable debug features
  static const bool isDebugMode = bool.fromEnvironment(
    'DEBUG_MODE',
    defaultValue: true,
  );

  /// API base URL
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.airo.dev',
  );

  /// Whether this is a development build
  static bool get isDev => environment == 'dev';

  /// Whether this is a staging build
  static bool get isStaging => environment == 'staging';

  /// Whether this is a production build
  static bool get isProd => environment == 'prod';

  /// Whether to show demo credentials in UI
  /// Only shown in dev/demo mode, never in production
  static bool get showDemoCredentials => isDemoMode && !isProd;
}

/// Build flavor configuration
enum BuildFlavor {
  development,
  staging,
  production,
}

/// Get current build flavor from environment
BuildFlavor get currentFlavor {
  switch (AppConfig.environment) {
    case 'prod':
      return BuildFlavor.production;
    case 'staging':
      return BuildFlavor.staging;
    default:
      return BuildFlavor.development;
  }
}

