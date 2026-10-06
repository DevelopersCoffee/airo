import 'package:airo_app/core/coins/coins_standalone_groups_list_screen.dart';
import 'package:airo_app/features/coins/application/providers/coins_currency_provider.dart';
import 'package:airo_app/features/coins/application/providers/group_providers.dart';
import 'package:core_app_shell/core_app_shell.dart';
import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../coins_currency_test_overrides.dart';
import '../test_support/fake_group_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('shows empty state actions for first-time users', (tester) async {
    final repository = FakeGroupRepository();

    await tester.pumpWidget(
      _routerHost(
        repository: repository,
        prefs: prefs,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const CoinsStandaloneGroupsListScreen(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No groups yet'), findsOneWidget);
    expect(find.text('Create Group'), findsWidgets);
    expect(find.text('Join with code'), findsOneWidget);
  });

  testWidgets('lists groups and navigates to detail route', (tester) async {
    final group = Group(
      id: 'trip',
      name: 'Goa Trip',
      creatorId: 'local_user',
      members: [
        GroupMember(
          id: 'm1',
          groupId: 'trip',
          userId: 'local_user',
          displayName: 'You',
          joinedAt: DateTime(2026, 10, 6),
        ),
      ],
      createdAt: DateTime(2026, 10, 6),
    );
    final repository = FakeGroupRepository(allGroups: [group]);

    await tester.pumpWidget(
      _routerHost(
        repository: repository,
        prefs: prefs,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const CoinsStandaloneGroupsListScreen(),
          ),
          GoRoute(
            path: '/groups/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Detail ${state.pathParameters['id']}')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Goa Trip'), findsOneWidget);
    expect(find.text('1 members'), findsOneWidget);

    await tester.tap(find.text('Goa Trip'));
    await tester.pumpAndSettle();

    expect(find.text('Detail trip'), findsOneWidget);
  });

  testWidgets('FAB opens the create-group dialog', (tester) async {
    final group = Group(
      id: 'trip',
      name: 'Goa Trip',
      creatorId: 'local_user',
      createdAt: DateTime(2026, 10, 6),
    );
    final repository = FakeGroupRepository(allGroups: [group]);

    await tester.pumpWidget(
      _routerHost(
        repository: repository,
        prefs: prefs,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const CoinsStandaloneGroupsListScreen(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Group'));
    await tester.pumpAndSettle();

    expect(find.text('Create Group'), findsWidgets);
    expect(find.text('Description'), findsOneWidget);
  });

  testWidgets('shows retry UI when group loading fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coinsCurrencyProviderTestOverride(prefs),
          allGroupsProvider.overrideWith(
            (ref) => Stream<List<Group>>.error('db down', StackTrace.empty),
          ),
        ],
        child: const MaterialApp(home: CoinsStandaloneGroupsListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Error: db down'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

Widget _routerHost({
  required FakeGroupRepository repository,
  required SharedPreferences prefs,
  required List<RouteBase> routes,
}) {
  final router = GoRouter(routes: routes);

  return ProviderScope(
    overrides: [
      coinsCurrencyProviderTestOverride(prefs),
      coinsCurrencyFormatterProvider.overrideWithValue(
        CurrencyFormatter.fromCode('USD'),
      ),
      groupRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}
