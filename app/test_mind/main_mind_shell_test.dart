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

import 'package:airo_app/core/mind/mind_shell.dart';
import 'package:airo_app/core/mind/mind_unavailable_screen.dart';
import 'package:airo_app/main_mind.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_mind/feature_mind.dart';
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
    expect(paths, contains(AssistantRouteNames.assistant));
  });

  test(
    'mind shell mounts the legacy /agent aliases the package still emits',
    () {
      // The package's tool registry and route connector still answer with the
      // pre-extraction `/agent*` paths, so the shell owns the same aliases the
      // super app's router owns. The targets are read off
      // [AssistantRouteNames] rather than spelled out: the hub's root moved
      // once already (Phase 3 claimed `/mind`) and a literal here would have
      // pinned the shell to the old one.
      expect(mindLegacyRedirects['/agent'], AssistantRouteNames.assistant);
      expect(
        mindLegacyRedirects['/agent/profile'],
        AssistantRouteNames.profile,
      );
      expect(mindLegacyRedirects['/agent/models'], AssistantRouteNames.models);
      expect(
        mindLegacyRedirects['/agent/notifications'],
        AssistantRouteNames.notifications,
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

  test('mind shell wraps its three destinations in one navigation shell', () {
    final routes = buildMindRoutes(buildMindModuleRegistry());

    final shellRoutes = routes.whereType<StatefulShellRoute>().toList();
    expect(
      shellRoutes,
      hasLength(1),
      reason: 'the bottom nav must be drawn once, by one shell route',
    );

    final branches = shellRoutes.single.branches;
    expect(branches, hasLength(MindShell.destinations.length));
    expect(
      branches
          .map((branch) => branch.routes.whereType<GoRoute>().first.path)
          .toList(),
      ['/', AssistantRouteNames.assistant, AssistantRouteNames.wellbeing],
      reason: 'branch order must match MindShell.destinations',
    );
  });

  test('mind shell mounts wellbeing exactly once', () {
    // MindModule.routesFor() returns scribe + hub + root routes combined, so
    // mounting `registry.allRoutes` *and* a wellbeing branch would register
    // `/wellbeing` twice. The shell assembles branches from the module's three
    // named accessors instead; this pins that it stayed that way.
    final paths = _allPaths(buildMindRoutes(buildMindModuleRegistry()));

    expect(
      paths.where((path) => path == AssistantRouteNames.wellbeing),
      hasLength(1),
    );
    expect(
      paths.where((path) => path == AssistantRouteNames.assistant),
      hasLength(1),
    );
    expect(paths.where((path) => path == '/'), hasLength(1));
  });

  test('mind shell labels its destinations Scribe, Assistant, Wellbeing', () {
    expect(
      MindShell.destinations.map((destination) => destination.label).toList(),
      ['Scribe', 'Assistant', 'Wellbeing'],
    );
  });

  testWidgets('tapping a destination switches branches', (tester) async {
    // Exercises MindShell against stand-in branch content: the real branch
    // roots are MindHomeScreen (which owns a microphone and model files) and
    // the assistant hub (which needs the host adapter's provider overrides),
    // neither of which belongs in a test of the navigation chrome. The real
    // branch wiring is covered by the structural tests above.
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MindShell(navigationShell: navigationShell),
          branches: [
            for (final path in const ['/', '/assistant', '/wellbeing'])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: path,
                    builder: (context, state) => Text('branch $path'),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Scribe'), findsOneWidget);
    expect(find.text('Assistant'), findsOneWidget);
    expect(find.text('Wellbeing'), findsOneWidget);
    expect(find.text('branch /'), findsOneWidget);

    await tester.tap(find.text('Assistant'));
    await tester.pumpAndSettle();
    expect(find.text('branch /assistant'), findsOneWidget);
    expect(router.state.uri.toString(), '/assistant');

    await tester.tap(find.text('Wellbeing'));
    await tester.pumpAndSettle();
    expect(find.text('branch /wellbeing'), findsOneWidget);
    expect(router.state.uri.toString(), '/wellbeing');

    await tester.tap(find.text('Scribe'));
    await tester.pumpAndSettle();
    expect(find.text('branch /'), findsOneWidget);
    expect(router.state.uri.toString(), '/');
  });

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

/// Every [GoRoute] path in [routes], walking children and shell branches.
List<String> _allPaths(List<RouteBase> routes) => [
  for (final route in routes) ...[
    if (route is GoRoute) route.path,
    if (route is StatefulShellRoute)
      ..._allPaths([for (final branch in route.branches) ...branch.routes])
    else
      ..._allPaths(route.routes),
  ],
];
