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
    // Home | Guide | Favorites | Settings.
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
                  path: '/mind',
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
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/guide',
                  builder: (context, state) =>
                      const _ShellBodyScreen(label: 'Guide body'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/favorites',
                  builder: (context, state) =>
                      const _ShellBodyScreen(label: 'Favorites body'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, state) =>
                      const _RouteOwnedScreen(title: 'Settings'),
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

  testWidgets('phone width shows exactly the 5 TV-matching destinations', (
    tester,
  ) async {
    await pumpShell(tester, initialLocation: '/home', width: 420);

    expect(find.byKey(const ValueKey('app_nav_home')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_live')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_guide')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_favorites')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_overflow')), findsNothing);

    // The other six domains are not part of the phone bottom nav.
    expect(find.byKey(const ValueKey('app_nav_coins')), findsNothing);
    expect(find.byKey(const ValueKey('app_nav_mind')), findsNothing);
    expect(find.byKey(const ValueKey('app_nav_beats')), findsNothing);
    expect(find.byKey(const ValueKey('app_nav_arena')), findsNothing);
    expect(find.byKey(const ValueKey('app_nav_quest')), findsNothing);

    expect(find.text('Home body'), findsOneWidget);
  });

  testWidgets('tapping a phone destination navigates to its branch', (
    tester,
  ) async {
    await pumpShell(tester, initialLocation: '/home', width: 420);

    await tester.tap(find.byKey(const ValueKey('app_nav_guide')));
    await tester.pumpAndSettle();

    expect(find.text('Guide body'), findsOneWidget);
  });

  testWidgets('wider layouts show the full ten-tab information architecture', (
    tester,
  ) async {
    await pumpShell(tester, initialLocation: '/home', width: 900);

    expect(find.byKey(const ValueKey('app_nav_coins')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_mind')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_beats')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_live')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_arena')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_quest')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_home')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_guide')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_favorites')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_overflow')), findsNothing);
  });
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
