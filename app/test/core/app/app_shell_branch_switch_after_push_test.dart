import 'package:airo_app/core/app/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Diagnostic repro for the AppShell staleness bug: push a route into a
/// StatefulShellRoute branch's own nested Navigator, then call
/// `navigationShell.goBranch()` from a bottom-sheet-style callback (mirrors
/// AppShell's real overflow sheet) and assert the shell chrome repaints
/// without needing an extra unrelated gesture.
void main() {
  Future<GoRouter> pumpShellRoute(
    WidgetTester tester, {
    required String initialLocation,
  }) async {
    late final GoRouter router;
    router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppShell(
              navigationShell: navigationShell,
              currentLocation: state.uri.path,
            );
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/money',
                  builder: (context, state) =>
                      const _ShellBodyScreen(label: 'Money body'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/assistant',
                  builder: (context, state) =>
                      const _ShellBodyScreen(label: 'Mind body'),
                  routes: [
                    GoRoute(
                      path: 'profile',
                      builder: (context, state) =>
                          const _RouteOwnedScreen(title: 'Profile'),
                    ),
                  ],
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
                      const _ShellBodyScreen(label: 'Games body'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/quest',
                  builder: (context, state) =>
                      const _ShellBodyScreen(label: 'Quest body'),
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
    return router;
  }

  testWidgets(
    'shell chrome repaints immediately after goBranch fired from a route '
    'pushed into another branch, without needing a later unrelated gesture',
    (tester) async {
      // Compact width: NavigationBar shows Coins/Assistant/Beats/Live plus a
      // "More" overflow entry (Arena, Quest, Home) -- this matches the phone
      // layout in the real repro.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = await pumpShellRoute(tester, initialLocation: '/money');

      // 1. Push a route that lives inside the Mind branch, from outside it
      // (mirrors AppShell.onProfileTap: context.push('/assistant/profile')
      // fired while the Coins branch is active).
      router.push('/assistant/profile');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Profile'), findsOneWidget);

      // 2. Open the overflow sheet from the NavigationBar and tap "Home" --
      // mirrors AppShell._showOverflowDestinations -> _goToTab ->
      // navigationShell.goBranch(home.index).
      await tester.tap(find.byKey(const ValueKey('app_nav_overflow')));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsWidgets);
      await tester.tap(find.widgetWithText(ListTile, 'Home'));

      // Pump exactly ONE frame (not pumpAndSettle) to check whether the
      // shell chrome repaints on the very next frame, the way a normal
      // go_router branch switch does -- not several frames/gestures later.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Home body'),
        findsOneWidget,
        reason:
            'AppShell should show the Home branch body on the next frame '
            'after goBranch(), not stay showing the pushed Profile route.',
      );
      expect(find.widgetWithText(AppBar, 'Profile'), findsNothing);
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
