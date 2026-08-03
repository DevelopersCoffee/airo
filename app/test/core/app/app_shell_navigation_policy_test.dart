import 'package:airo_app/core/app/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    required String initialLocation,
    required double width,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Branch order must mirror AppNavigationTab.values in
    // navigation_provider.dart: Coins | Mind | Beats | Live | Arena | Quest |
    // Home.
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return ProviderScope(
              child: AppShell(
                navigationShell: navigationShell,
                currentLocation: state.uri.path,
              ),
            );
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/money',
                  builder: (context, state) =>
                      const _ShellBodyScreen(label: 'Coins body'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/assistant',
                  builder: (context, state) =>
                      const _ShellBodyScreen(label: 'Mind body'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/music',
                  builder: (context, state) =>
                      const _RouteOwnedScreen(title: 'Beats'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/iptv',
                  builder: (context, state) =>
                      const _RouteOwnedScreen(title: 'Live'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/games',
                  builder: (context, state) =>
                      const _ShellBodyScreen(label: 'Arena body'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/quest',
                  builder: (context, state) =>
                      const _RouteOwnedScreen(title: 'Quest'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) =>
                      const _ShellBodyScreen(label: 'Home body'),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone width preserves Airo super-app primary destinations', (
    tester,
  ) async {
    await pumpShell(tester, initialLocation: '/money', width: 420);

    expect(find.byKey(const ValueKey('app_nav_coins')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_assistant')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_beats')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_live')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_overflow')), findsOneWidget);

    // Secondary domains stay reachable through More instead of adopting the
    // separate Airo TV shell's primary navigation.
    expect(find.byKey(const ValueKey('app_nav_arena')), findsNothing);
    expect(find.byKey(const ValueKey('app_nav_quest')), findsNothing);
    expect(find.byKey(const ValueKey('app_nav_home')), findsNothing);

    expect(find.text('Coins body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone overflow navigates to a secondary Airo branch', (
    tester,
  ) async {
    await pumpShell(tester, initialLocation: '/money', width: 420);

    await tester.tap(find.byKey(const ValueKey('app_nav_overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('app_nav_overflow_entry_home')));
    await tester.pumpAndSettle();

    expect(find.text('Home body'), findsOneWidget);
  });

  testWidgets(
    'wider layouts show a curated 6-tab set, excluding the placeholder '
    'Home tab (Guide/Favorites live inside IPTV, Settings via the profile '
    'menu)',
    (tester) async {
      // Wide layouts don't have a /home branch in their nav bar, so start
      // from a destination that is actually part of the wide tab set.
      await pumpShell(tester, initialLocation: '/assistant', width: 900);

      expect(find.byKey(const ValueKey('app_nav_coins')), findsOneWidget);
      expect(find.byKey(const ValueKey('app_nav_assistant')), findsOneWidget);
      expect(find.byKey(const ValueKey('app_nav_beats')), findsOneWidget);
      expect(find.byKey(const ValueKey('app_nav_live')), findsOneWidget);
      expect(find.byKey(const ValueKey('app_nav_arena')), findsOneWidget);
      expect(find.byKey(const ValueKey('app_nav_quest')), findsOneWidget);
      expect(find.byKey(const ValueKey('app_nav_overflow')), findsNothing);

      // Home is a phone-only placeholder (Mind already covers this ground
      // on wide layouts), so it gets no persistent destination on wide
      // layouts either.
      expect(find.byKey(const ValueKey('app_nav_home')), findsNothing);
    },
  );
}

class _ShellBodyScreen extends StatelessWidget {
  const _ShellBodyScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(child: Text(label)),
    );
  }
}

class _RouteOwnedScreen extends StatelessWidget {
  const _RouteOwnedScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title body')),
    );
  }
}
