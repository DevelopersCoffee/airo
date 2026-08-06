/// Tests for the standalone Airo Mind shell.
///
/// These live outside `app/test/` on purpose. Flavors are separate pubspecs
/// in this repo, and `feature_mind` is deliberately *not* a dependency of
/// `app/pubspec.yaml` (it declares cargokit hooks, so every phone build would
/// cross-compile whisper.cpp and llama.cpp — see the exclusion note in
/// `app/analysis_options.yaml`). `flutter test` with no arguments only walks
/// `test/`, so the default phone suite stays green while this suite runs
/// under the Mind flavour:
///
/// ```bash
/// cp app/pubspec_mind.yaml app/pubspec.yaml   # restored by run_mind_macos.sh
/// cd app && flutter pub get && flutter test test_mind/
/// ```
library;

import 'package:airo_app/core/mind/mind_unavailable_screen.dart';
import 'package:airo_app/main_mind.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('mind registry registers scribe and assistant modules', () {
    final registry = buildMindModuleRegistry();

    expect(registry.shell, ShellId.mind);
    expect(registry.moduleIds, containsAll(['mind_scribe', 'assistant']));

    final paths = registry.allRoutes.whereType<GoRoute>().map((r) => r.path);
    expect(paths, contains('/'));
    expect(paths, contains('/assistant'));
  });

  test(
    'mind shell mounts the legacy /agent aliases the package still emits',
    () {
      // The assistant package's tool registry and route connector still answer
      // with the pre-extraction `/agent*` paths, so the shell owns the same
      // aliases the super app's router owns.
      expect(mindLegacyRedirects['/agent'], '/assistant');
      expect(mindLegacyRedirects['/agent/profile'], '/assistant/profile');
      expect(mindLegacyRedirects['/agent/models'], '/assistant/models');
      expect(
        mindLegacyRedirects['/agent/notifications'],
        '/assistant/notifications',
      );

      final paths = buildMindRoutes(
        buildMindModuleRegistry(),
      ).whereType<GoRoute>().map((route) => route.path).toSet();
      expect(paths, containsAll(mindLegacyRedirects.keys));
    },
  );

  test(
    'mind shell mounts the account routes its host adapter navigates to',
    () {
      // AppAssistantHostAdapter.signOutAndReturnToLogin() does
      // `context.go('/login')`; LoginScreen in turn pushes '/register'. Both
      // must resolve here or signing out strands the user on an error page.
      final paths = buildMindRoutes(
        buildMindModuleRegistry(),
      ).whereType<GoRoute>().map((route) => route.path).toSet();

      expect(paths, containsAll(['/login', '/register']));
    },
  );

  testWidgets('super-app destinations degrade to the Mind explainer', (
    tester,
  ) async {
    // Every super-app path the assistant package can emit but this shell does
    // not mount (tool registry routes, the Settings tile on ProfileScreen).
    for (final location in const [
      '/games',
      '/quest/new',
      '/money',
      '/live/music',
      '/reader',
      '/settings',
    ]) {
      final router = buildMindRouter(initialLocation: location);
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      expect(
        find.byType(MindUnavailableScreen),
        findsOneWidget,
        reason: '$location must degrade instead of throwing a route error',
      );
      expect(find.textContaining(location), findsWidgets);
    }
  });
}
