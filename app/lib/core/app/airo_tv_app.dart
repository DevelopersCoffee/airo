/// TV-specific app shell for Android TV / Fire TV
///
/// Optimizations for TV:
/// - Landscape-only orientation (enforced in main_tv.dart)
/// - No bottom navigation (uses sidebar/grid navigation)
/// - D-pad focus management enabled by default
/// - Larger touch targets (64dp minimum)
/// - No audio service (TV uses system audio)
/// - Immersive fullscreen mode
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/global_error_handler.dart';
import '../platform/platform_config.dart';
import '../providers/app_theme_provider.dart';
import '../tv/tv.dart';
import 'tv_router.dart';

/// TV-specific app for IPTV-only experience
class AiroTvApp extends ConsumerStatefulWidget {
  const AiroTvApp({super.key});

  @override
  ConsumerState<AiroTvApp> createState() => _AiroTvAppState();
}

class _AiroTvAppState extends ConsumerState<AiroTvApp> {
  @override
  void initState() {
    super.initState();
    // Set the navigator key for global error handler after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigatorKey = TvRouter.router.routerDelegate.navigatorKey;
      GlobalErrorHandler.setNavigatorKey(navigatorKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get TV focus manager
    final focusManager = ref.watch(tvFocusManagerProvider);
    final selectedTheme = ref.watch(appThemeDefinitionProvider);

    return MaterialApp.router(
      title: 'Airo TV',
      theme: _buildTvTheme(selectedTheme.lightTheme),
      darkTheme: _buildTvTheme(selectedTheme.darkTheme),
      themeMode: selectedTheme.themeMode,
      routerConfig: TvRouter.router,
      debugShowCheckedModeBanner: false,
      // TV-specific scroll behavior
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const ClampingScrollPhysics(),
        scrollbars: false, // Hide scrollbars on TV
      ),
      builder: (context, child) {
        // Wrap entire app with TV input handler for global key handling
        return TvInputHandler(
          onInput: (key) => _handleGlobalInput(key, focusManager),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  /// Handle global TV input (before route-specific handlers)
  TvInputResult _handleGlobalInput(
    TvInputKey key,
    TvFocusManager focusManager,
  ) {
    // Let the focus manager handle D-pad navigation
    if (key.isNavigationKey) {
      final direction = switch (key) {
        TvInputKey.up => TraversalDirection.up,
        TvInputKey.down => TraversalDirection.down,
        TvInputKey.left => TraversalDirection.left,
        TvInputKey.right => TraversalDirection.right,
        _ => null,
      };

      if (direction != null && focusManager.navigate(direction)) {
        return TvInputResult.handled;
      }
    }

    // Pass through to let child widgets handle
    return TvInputResult.notHandled;
  }

  /// Build TV-optimized theme
  ThemeData _buildTvTheme(ThemeData baseTheme) {
    final theme = PlatformConfig.adjustThemeForPlatform(baseTheme);

    return theme.copyWith(
      // Larger text for 10-foot UI
      textTheme: theme.textTheme.apply(
        fontSizeFactor: 1.2, // 20% larger text for TV viewing distance
      ),
      // TV-specific component themes
      cardTheme: theme.cardTheme.copyWith(
        elevation: 4,
        margin: const EdgeInsets.all(8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(120, 56), // Larger touch targets
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: theme.textTheme.titleMedium,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(56, 56), // 56dp minimum for D-pad
          padding: const EdgeInsets.all(16),
        ),
      ),
      // Focus indicator
      focusColor: theme.colorScheme.primary.withValues(alpha: 0.3),
      hoverColor: theme.colorScheme.primary.withValues(alpha: 0.1),
    );
  }
}
