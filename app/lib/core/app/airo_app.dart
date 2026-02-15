import 'package:flutter/material.dart';
import '../error/global_error_handler.dart';
import '../routing/app_router.dart';
import '../theme/app_theme.dart';
import '../platform/platform_config.dart';

class AiroApp extends StatefulWidget {
  const AiroApp({super.key});

  @override
  State<AiroApp> createState() => _AiroAppState();
}

class _AiroAppState extends State<AiroApp> {
  @override
  void initState() {
    super.initState();
    // Set the navigator key for global error handler after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigatorKey = AppRouter.router.routerDelegate.navigatorKey;
      GlobalErrorHandler.setNavigatorKey(navigatorKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Airo Super App',
      theme: PlatformConfig.adjustThemeForPlatform(AppTheme.light),
      darkTheme: PlatformConfig.adjustThemeForPlatform(AppTheme.dark),
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
