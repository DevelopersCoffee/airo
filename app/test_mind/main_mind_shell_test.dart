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

  test('mind shell wraps its destinations in one navigation shell', () {
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
      ['/', AssistantRouteNames.assistant, '/models', '/settings'],
      reason: 'branch order must match MindShell.destinations',
    );
  });

  test('mind shell does not mount a wellbeing branch', () {
    // Wellbeing is a chat skill on ShellId.mind, so rootRoutesFor is empty.
    // Mounting that empty list as a StatefulShellBranch crashes go_router
    // (initialLocation cannot be derived). Leftover /wellbeing links redirect
    // onto the hub instead of registering a Wellbeing tab.
    final routes = buildMindRoutes(buildMindModuleRegistry());
    final shell = routes.whereType<StatefulShellRoute>().single;
    final branchPaths = [
      for (final branch in shell.branches)
        ...branch.routes.whereType<GoRoute>().map((route) => route.path),
    ];

    expect(branchPaths, isNot(contains(AssistantRouteNames.wellbeing)));
    expect(
      branchPaths.where((path) => path == AssistantRouteNames.assistant),
      hasLength(1),
    );
    expect(branchPaths.where((path) => path == '/'), hasLength(1));
  });

  testWidgets('mind shell rewrites leftover /wellbeing links onto the hub', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    final router = buildMindRouter();
    addTearDown(router.dispose);
    final route = buildMindRoutes(buildMindModuleRegistry())
        .whereType<GoRoute>()
        .firstWhere((r) => r.path == AssistantRouteNames.wellbeing);
    final state = GoRouterState(
      router.configuration,
      uri: Uri.parse(AssistantRouteNames.wellbeing),
      matchedLocation: AssistantRouteNames.wellbeing,
      fullPath: route.path,
      pathParameters: const {},
      pageKey: const ValueKey('test'),
    );

    expect(
      await route.redirect!(context, state),
      AssistantRouteNames.assistant,
    );
  });

  testWidgets('mind hub models child redirects onto the Intelligence tab', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    final router = buildMindRouter();
    addTearDown(router.dispose);
    final hub = buildMindRoutes(buildMindModuleRegistry())
        .whereType<StatefulShellRoute>()
        .single
        .branches[1]
        .routes
        .whereType<GoRoute>()
        .first;
    final models = hub.routes.whereType<GoRoute>().firstWhere(
      (route) => route.path == AssistantRouteNames.modelsSegment,
    );
    final state = GoRouterState(
      router.configuration,
      uri: Uri.parse(AssistantRouteNames.models),
      matchedLocation: AssistantRouteNames.models,
      fullPath: '${hub.path}/${models.path}',
      pathParameters: const {},
      pageKey: const ValueKey('test'),
    );

    expect(await models.redirect!(context, state), '/models');
  });

  test(
    'mind shell labels its destinations Scribe, Assistant, Intelligence, Settings',
    () {
      expect(
        MindShell.destinations.map((destination) => destination.label).toList(),
        ['Scribe', 'Assistant', 'Intelligence', 'Settings'],
      );
    },
  );

  testWidgets('tapping a destination switches branches', (tester) async {
    // Exercises MindShell against stand-in branch content: the real branch
    // roots are MindHomeScreen (which owns a microphone and model files) and
    // the assistant hub (which needs the host adapter's provider overrides),
    // neither of which belongs in a test of the navigation chrome. The real
    // branch wiring is covered by the structural tests above.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _mindChromeRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    Finder barLabel(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );
    expect(barLabel('Scribe'), findsOneWidget);
    expect(barLabel('Assistant'), findsOneWidget);
    expect(barLabel('Intelligence'), findsOneWidget);
    expect(barLabel('Settings'), findsOneWidget);
    expect(find.text('Wellbeing'), findsNothing);
    expect(find.text('branch /'), findsOneWidget);

    await tester.tap(barLabel('Assistant'));
    await tester.pumpAndSettle();
    expect(find.text('branch /assistant'), findsOneWidget);
    expect(router.state.uri.toString(), '/assistant');

    await tester.tap(barLabel('Intelligence'));
    await tester.pumpAndSettle();
    expect(find.text('branch /models'), findsOneWidget);
    expect(router.state.uri.toString(), '/models');

    await tester.tap(barLabel('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('branch /settings'), findsOneWidget);
    expect(router.state.uri.toString(), '/settings');

    await tester.tap(barLabel('Scribe'));
    await tester.pumpAndSettle();
    expect(find.text('branch /'), findsOneWidget);
    expect(router.state.uri.toString(), '/');
  });

  testWidgets('wide mind shell uses a navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _mindChromeRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byKey(const ValueKey('mind_nav_menu')), findsNothing);
    expect(find.text('Offline models'), findsNothing);
    expect(find.text('Intelligence'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Intelligence'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('branch /models'), findsOneWidget);
    expect(router.state.uri.toString(), '/models');
  });

  testWidgets(
    'iPad portrait uses a rail and does not duplicate destinations in a drawer',
    (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = _mindChromeRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(Drawer), findsNothing);
      expect(find.byKey(const ValueKey('mind_nav_menu')), findsNothing);
      expect(find.text('Scribe'), findsOneWidget);
      expect(find.text('Assistant'), findsOneWidget);
      expect(find.text('Intelligence'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Offline models'), findsNothing);
    },
  );

  testWidgets('compact mind shell uses a bar and no drawer', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _mindChromeRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byKey(const ValueKey('mind_nav_menu')), findsNothing);
    expect(find.text('Offline models'), findsNothing);
  });

  testWidgets('super-app destinations degrade to the Mind explainer', (
    tester,
  ) async {
    // Every super-app path the assistant package can emit but this shell does
    // not mount (tool registry routes). Settings is a Mind tab.
    for (final location in const [
      '/games',
      '/quest/new',
      '/money',
      '/live/music',
      '/reader',
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

GoRouter _mindChromeRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MindShell(navigationShell: navigationShell),
        branches: [
          for (final path in const ['/', '/assistant', '/models', '/settings'])
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
}
