import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:feature_mind/feature_mind.dart';
import '../error/global_error_handler.dart';
import '../providers/app_theme_provider.dart';
import '../platform/platform_config.dart';

class AiroApp extends ConsumerStatefulWidget {
  const AiroApp({required this.router, super.key});

  final GoRouter router;

  @override
  ConsumerState<AiroApp> createState() => _AiroAppState();
}

class _AiroAppState extends ConsumerState<AiroApp> {
  @override
  void initState() {
    super.initState();
    // Set the navigator key for global error handler after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigatorKey = widget.router.routerDelegate.navigatorKey;
      GlobalErrorHandler.setNavigatorKey(navigatorKey);
      unawaited(
        NotificationNavigationService.instance
            .bind(navigate: widget.router.go)
            .catchError((Object error, StackTrace stackTrace) {
              debugPrint('Notification navigation unavailable: $error');
            }),
      );
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
      routerConfig: widget.router,
      debugShowCheckedModeBanner: false,
      // Platform-specific scroll behavior
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: PlatformConfig.getScrollPhysics(),
      ),
    );
  }
}
