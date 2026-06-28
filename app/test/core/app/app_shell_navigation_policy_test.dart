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
                      const _RouteOwnedScreen(title: 'Stream'),
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
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('compact phones use shared overflow for lower-frequency tabs', (
    tester,
  ) async {
    await pumpShell(tester, initialLocation: '/money', width: 420);

    expect(find.byKey(const ValueKey('app_nav_coins')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_mind')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_beats')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_stream')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_overflow')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_arena')), findsNothing);
    expect(find.byKey(const ValueKey('app_nav_quest')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('app_nav_overflow')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('app_nav_overflow_entry_arena')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('app_nav_overflow_entry_quest')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('app_nav_overflow_entry_quest')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quest body'), findsOneWidget);
  });

  testWidgets('wider layouts keep all primary destinations visible', (
    tester,
  ) async {
    await pumpShell(tester, initialLocation: '/money', width: 900);

    expect(find.byKey(const ValueKey('app_nav_coins')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_mind')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_beats')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_stream')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_arena')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_quest')), findsOneWidget);
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
