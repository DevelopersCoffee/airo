import 'package:airo_app/core/app/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> pumpShellRoute(
    WidgetTester tester, {
    required String initialLocation,
  }) async {
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
                      const _ShellBodyScreen(label: 'Money body'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/mind',
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
                      const _RouteOwnedScreen(title: 'Stream'),
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
                      const _RouteOwnedScreen(title: 'Quest'),
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

  testWidgets('shows shell chrome on shell-owned root routes', (tester) async {
    await pumpShellRoute(tester, initialLocation: '/mind');

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Mind'), findsOneWidget);
    expect(find.byKey(const ValueKey('app_shell_home_button')), findsOneWidget);
    expect(find.text('Mind body'), findsOneWidget);
  });

  testWidgets('hides shell chrome on route-owned root routes', (tester) async {
    await pumpShellRoute(tester, initialLocation: '/music');

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Beats'), findsOneWidget);
    expect(find.byKey(const ValueKey('app_shell_home_button')), findsNothing);
  });

  testWidgets('hides shell chrome on nested route-owned screens', (
    tester,
  ) async {
    await pumpShellRoute(tester, initialLocation: '/mind/profile');

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Profile'), findsOneWidget);
    expect(find.byKey(const ValueKey('app_shell_home_button')), findsNothing);
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
