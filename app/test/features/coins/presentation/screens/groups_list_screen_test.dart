import 'package:airo_app/features/coins/application/providers/cloud_mode_provider.dart';
import 'package:airo_app/features/coins/application/providers/coins_currency_provider.dart';
import 'package:airo_app/features/coins/application/providers/coins_identity_provider.dart';
import 'package:airo_app/features/coins/application/providers/group_providers.dart';
import 'package:airo_app/features/coins/presentation/screens/groups_list_screen.dart';
import 'package:core_app_shell/core_app_shell.dart';
import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../coins_currency_test_overrides.dart';
import '../../test_support/fake_group_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('shows cloud mode card and empty groups guidance', (
    tester,
  ) async {
    final repository = FakeGroupRepository();

    await tester.pumpWidget(
      _host(
        repository: repository,
        prefs: prefs,
        cloudState: const CoinsCloudModeState(mode: CoinsStorageMode.local),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local-first mode'), findsOneWidget);
    expect(find.text('No groups yet'), findsOneWidget);
    expect(find.text('Create Group'), findsWidgets);
  });

  testWidgets('renders group cards with currency labels', (tester) async {
    final group = Group(
      id: 'trip',
      name: 'Weekend trip',
      creatorId: 'local_user',
      members: [
        GroupMember(
          id: 'm1',
          groupId: 'trip',
          userId: 'local_user',
          displayName: 'You',
          joinedAt: DateTime(2026, 10, 6),
        ),
        GroupMember(
          id: 'm2',
          groupId: 'trip',
          userId: 'friend',
          displayName: 'Friend',
          joinedAt: DateTime(2026, 10, 6),
        ),
      ],
      createdAt: DateTime(2026, 10, 6),
    );
    final repository = FakeGroupRepository(allGroups: [group]);

    await tester.pumpWidget(
      _host(
        repository: repository,
        prefs: prefs,
        cloudState: const CoinsCloudModeState(mode: CoinsStorageMode.local),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekend trip'), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget);
    expect(find.textContaining(r'$0.00'), findsOneWidget);
  });

  testWidgets('opens the create-group dialog from the app bar actions', (
    tester,
  ) async {
    final repository = FakeGroupRepository();

    await tester.pumpWidget(
      _host(
        repository: repository,
        prefs: prefs,
        cloudState: const CoinsCloudModeState(mode: CoinsStorageMode.local),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Join with Code'));
    await tester.pumpAndSettle();

    expect(find.text('Invite code or QR link'), findsOneWidget);
  });
}

Widget _host({
  required FakeGroupRepository repository,
  required SharedPreferences prefs,
  required CoinsCloudModeState cloudState,
}) {
  return ProviderScope(
    overrides: [
      coinsCurrencyProviderTestOverride(prefs),
      coinsCurrencyFormatterProvider.overrideWithValue(
        CurrencyFormatter.fromCode('USD'),
      ),
      groupRepositoryProvider.overrideWithValue(repository),
      coinsIdentityProvider.overrideWithValue(_LocalIdentity()),
      coinsCloudModeControllerProvider.overrideWith(
        (ref) => _FixedCloudController(cloudState),
      ),
    ],
    child: const MaterialApp(home: GroupsListScreen()),
  );
}

class _LocalIdentity implements CoinsIdentity {
  @override
  CoinsUser? get current => const CoinsUser(
    id: 'local_user',
    username: 'You',
    isGoogleIdentity: false,
  );

  @override
  Future<CoinsSignInResult> signInWithGoogle() async {
    return const CoinsSignInResult.failure('offline');
  }
}

class _FixedCloudController extends CoinsCloudModeController {
  _FixedCloudController(CoinsCloudModeState initial) : super(_LocalIdentity()) {
    state = AsyncValue.data(initial);
  }

  @override
  Future<bool> enableCloudMode() async => false;

  @override
  Future<void> useLocalMode() async {
    state = AsyncValue.data(
      (state.value ?? const CoinsCloudModeState(mode: CoinsStorageMode.local))
          .copyWith(mode: CoinsStorageMode.local),
    );
  }
}
