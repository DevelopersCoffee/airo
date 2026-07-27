/// Shared app-shell infrastructure used across product shells: theme
/// selection, deferred startup-task scheduling, platform-feature
/// configuration, and device form-factor detection. No app-specific UI or
/// composition lives here — see ADR-0011 and
/// `tasks/ssot_airo_airo_tv_architecture_blueprint.md`.
library;

export 'src/app_theme_provider.dart';
export 'src/currency_formatter.dart';
export 'src/deferred_startup_task.dart';
export 'src/device_form_factor.dart';
export 'src/locale_settings.dart';
export 'src/platform_features.dart';
