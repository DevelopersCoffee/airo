import 'package:flutter/material.dart';
import '../routing/app_router.dart';
import '../theme/app_theme.dart';
import '../platform/platform_config.dart';

class AiroApp extends StatelessWidget {
  const AiroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Airo Super App',
      theme: PlatformConfig.adjustThemeForPlatform(AppTheme.lightTheme),
      darkTheme: PlatformConfig.adjustThemeForPlatform(AppTheme.darkTheme),
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
      // Platform-specific scroll behavior
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: PlatformConfig.getScrollPhysics(),
      ),
    );
  }
}
