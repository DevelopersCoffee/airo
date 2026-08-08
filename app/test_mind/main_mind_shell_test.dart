/// Tests for the standalone Airo Mind shell.
///
/// These live outside `app/test/` on purpose. Flavors are separate pubspecs
/// in this repo, and `feature_mind` declares cargokit hooks — every phone
/// build cross-compiles whisper.cpp and llama.cpp now that the merged package
/// carries the assistant hub too
/// (`docs/superpowers/plans/2026-08-07-airo-mind-ssot-plan.md`, Phase 2), but
/// this suite still needs the Mind flavour's own pubspec and dart-define, not
/// the phone default. `flutter test` with no arguments only walks `test/`, so
/// the default phone suite stays green while this suite runs under the Mind
/// flavour:
///
/// ```bash
/// cp app/pubspec_mind.yaml app/pubspec.yaml   # restored by run_mind_macos.sh
/// cd app && flutter pub get
/// flutter test test_mind/ --dart-define=APP_VARIANT=mind
/// ```
library;

import 'package:airo_app/core/mind/mind_unavailable_screen.dart';
import 'package:airo_app/main_mind.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('mind registry registers the merged scribe + assistant module', () {
    final registry = buildMindModuleRegistry();

    expect(registry.shell, ShellId.mind);
    expect(registry.moduleIds, ['mind']);

    final paths = registry.allRoutes.whereType<GoRoute>().map((r) => r.path);
    expect(paths, contains('/'));
    expect(paths, contains('/mind'));
  });

  testWidgets(
    'mind shell rewrites every legacy /agent and /assistant destination',
    (tester) async {
      // The assistant package's tool registry and route connector still answer
      // with the pre-extraction `/agent*` paths, and `/assistant*` was the
      // hub's home before Phase 3 claimed `/mind` — both must keep resolving,
      // including the seven children an earlier, four-entry version of this
      // redirect table let fall through to a 404.
      //
      // Calls each matching route's own `redirect` closure directly rather
      // than driving live navigation: `/mind` and its children render real
      // screens that need providers this test's bare `MaterialApp.router`
      // does not set up, and none of that is what this test is checking.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      final router = buildMindRouter();
      addTearDown(router.dispose);
      final routes = buildMindRoutes(
        buildMindModuleRegistry(),
      ).whereType<GoRoute>().toList();

      const cases = <String, String>{
        '/agent': '/mind',
        '/agent/notifications': '/mind/notifications',
        '/agent/profile': '/mind/profile',
        '/agent/models': '/mind/models',
        '/agent/skills': '/mind/skills',
        '/agent/prompt-lab': '/mind/prompt-lab',
        '/assistant': '/mind',
        '/assistant/chat': '/mind/chat',
        '/assistant/audio-scribe': '/mind/audio-scribe',
      };

      for (final entry in cases.entries) {
        final segments = entry.key
            .split('/')
            .where((s) => s.isNotEmpty)
            .toList();
        final route = routes.firstWhere((r) {
          final routeSegments = r.path
              .split('/')
              .where((s) => s.isNotEmpty)
              .toList();
          if (routeSegments.length != segments.length) return false;
          for (var i = 0; i < routeSegments.length; i++) {
            if (!routeSegments[i].startsWith(':') &&
                routeSegments[i] != segments[i]) {
              return false;
            }
          }
          return true;
        });

        final rest = segments.length > 1 ? segments.skip(1).join('/') : '';
        final state = GoRouterState(
          router.configuration,
          uri: Uri.parse(entry.key),
          matchedLocation: entry.key,
          fullPath: route.path,
          pathParameters: rest.isEmpty ? const {} : {'rest': rest},
          pageKey: const ValueKey('test'),
        );

        expect(
          await route.redirect!(context, state),
          entry.value,
          reason: '${entry.key} must redirect to ${entry.value}',
        );
      }
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
