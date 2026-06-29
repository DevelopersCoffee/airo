import 'package:flutter/material.dart';

import 'app_theme_id.dart';

/// User-selectable theme metadata plus concrete Flutter theme data.
@immutable
class AppThemeDefinition {
  const AppThemeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.lightTheme,
    required this.darkTheme,
    required this.themeMode,
  });

  final AppThemeId id;
  final String name;
  final String description;
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final ThemeMode themeMode;
}
