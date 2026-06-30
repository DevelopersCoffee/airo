import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_core/platform_core.dart';
import 'package:design_system/core_ui.dart';

import 'startup_screen.dart';
import 'error_screen.dart';
import 'ready_screen.dart';
import 'diagnostics_overlay.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lifecycleState = ref.watch(bootstrapCoordinatorProvider);
    final report = ref.watch(bootstrapReportProvider);

    Widget activeScreen;

    switch (lifecycleState) {
      case LifecycleState.created:
      case LifecycleState.initializing:
        activeScreen = const StartupScreen();
        break;
      case LifecycleState.failed:
        activeScreen = ErrorScreen(
          error: report?.fatalError ?? 'Unknown fatal error',
          onRestart: () {
            // Re-trigger bootstrap
            ref.invalidate(bootstrapCoordinatorProvider);
            ref.read(bootstrapCoordinatorProvider.notifier).execute(ProviderScope.containerOf(context));
          },
        );
        break;
      case LifecycleState.ready:
        activeScreen = const ReadyScreen();
        break;
      default:
        activeScreen = const StartupScreen();
    }

    // We wrap it with MaterialApp since go_router belongs to Program 1
    // As instructed: Single route `/`
    return MaterialApp(
      title: 'AIRO',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: DiagnosticsOverlayWrapper(child: activeScreen),
      debugShowCheckedModeBanner: false,
    );
  }
}
