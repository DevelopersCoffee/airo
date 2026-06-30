import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../error/global_error_handler.dart';
import '../providers/app_theme_provider.dart';
import '../routing/app_router.dart';
import '../platform/platform_config.dart';

class AiroApp extends ConsumerStatefulWidget {
  const AiroApp({super.key});

  @override
  ConsumerState<AiroApp> createState() => _AiroAppState();
}

class _AiroAppState extends ConsumerState<AiroApp> {
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
    final themeDefinition = ref.watch(appThemeDefinitionProvider);

    return MaterialApp.router(
      title: 'Airo Super App',
      theme: PlatformConfig.adjustThemeForPlatform(themeDefinition.lightTheme),
      darkTheme: PlatformConfig.adjustThemeForPlatform(
        themeDefinition.darkTheme,
      ),
      themeMode: themeDefinition.themeMode,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
      // Platform-specific scroll behavior
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: PlatformConfig.getScrollPhysics(),
      ),
    );
  }
}
