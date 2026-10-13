import 'package:airo_app/features/coins/application/providers/cloud_mode_provider.dart';
import 'package:airo_app/features/coins/application/providers/coins_identity_provider.dart';
import 'package:airo_app/features/coins/application/providers/group_providers.dart';
import 'package:airo_app/features/coins/presentation/screens/group_detail_cloud_share.dart';
import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_support/fake_group_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  const groupId = 'group_share';

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
  });

  testWidgets('does nothing when the user declines cloud sharing', (
    tester,
  ) async {
    var shared = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (_) async {
          shared = true;
          return null;
        });

    final repository = FakeGroupRepository();
    final identity = _FakeIdentity(
      current: const CoinsUser(
        id: 'local',
        username: 'You',
        isGoogleIdentity: false,
      ),
    );

    await tester.pumpWidget(
      _host(
        repository: repository,
        identity: identity,
        cloudState: const CoinsCloudModeState(
          mode: CoinsStorageMode.local,
          user: const CoinsUser(
            id: 'local',
            username: 'You',
            isGoogleIdentity: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Share invite'));
    await tester.pumpAndSettle();

    expect(find.text('Switch to cloud sharing?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(shared, isFalse);
    expect(repository.lastGenerateInviteGroupId, isNull);
  });

  testWidgets('shares after enabling cloud mode with a Google identity', (
    tester,
  ) async {
    var sharedText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
          sharedText = call.arguments['text'] as String? ?? '';
          return null;
        });

    final repository = FakeGroupRepository();
    final identity = _FakeIdentity(
      signInResult: const CoinsSignInResult.success(
        CoinsUser(
          id: 'google-1',
          email: 'ada@example.com',
          username: 'Ada',
          isGoogleIdentity: true,
        ),
      ),
    );

    await tester.pumpWidget(
      _host(
        repository: repository,
        identity: identity,
        cloudState: const CoinsCloudModeState(
          mode: CoinsStorageMode.local,
          user: const CoinsUser(
            id: 'local',
            username: 'You',
            isGoogleIdentity: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Share invite'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use Cloud'));
    await tester.pumpAndSettle();

    expect(identity.signInCalls, 1);
    expect(repository.lastGenerateInviteGroupId, groupId);
    expect(sharedText, contains('Join Roommates on Airo Coins'));
    expect(sharedText, contains('INVITE01'));
  });

  testWidgets('uses existing invite codes when cloud mode is already on', (
    tester,
  ) async {
    var sharedText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
          sharedText = call.arguments['text'] as String? ?? '';
          return null;
        });

    final repository = FakeGroupRepository();
    const googleUser = CoinsUser(
      id: 'google-1',
      email: 'ada@example.com',
      username: 'Ada',
      isGoogleIdentity: true,
    );

    await tester.pumpWidget(
      _host(
        repository: repository,
        identity: _FakeIdentity(current: googleUser),
        cloudState: const CoinsCloudModeState(
          mode: CoinsStorageMode.cloud,
          user: googleUser,
        ),
        inviteCode: 'READY123',
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Share invite'));
    await tester.pumpAndSettle();

    expect(repository.lastGenerateInviteGroupId, isNull);
    expect(sharedText, contains('READY123'));
  });

  testWidgets('shows snackbar when invite generation fails', (tester) async {
    final repository = FakeGroupRepository(
      generateInviteResult: (data: null, error: 'quota exceeded'),
    );
    const googleUser = CoinsUser(
      id: 'google-1',
      email: 'ada@example.com',
      username: 'Ada',
      isGoogleIdentity: true,
    );

    await tester.pumpWidget(
      _host(
        repository: repository,
        identity: _FakeIdentity(current: googleUser),
        cloudState: const CoinsCloudModeState(
          mode: CoinsStorageMode.cloud,
          user: googleUser,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Share invite'));
    await tester.pumpAndSettle();

    expect(find.text('quota exceeded'), findsOneWidget);
  });
}

Widget _host({
  required FakeGroupRepository repository,
  required _FakeIdentity identity,
  required CoinsCloudModeState cloudState,
  String? inviteCode,
  String groupId = 'group_share',
}) {
  final group = Group(
    id: groupId,
    name: 'Roommates',
    creatorId: 'google-1',
    inviteCode: inviteCode,
    createdAt: DateTime(2026, 10, 6),
  );

  return ProviderScope(
    overrides: [
      groupRepositoryProvider.overrideWithValue(repository),
      coinsIdentityProvider.overrideWithValue(identity),
      coinsCloudModeControllerProvider.overrideWith(
        (ref) => _FixedCloudController(identity, cloudState),
      ),
    ],
    child: MaterialApp(home: _ShareHost(group: group)),
  );
}

class _ShareHost extends ConsumerWidget {
  const _ShareHost({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async => shareGroupInviteWithCloud(context, ref, group),
          child: const Text('Share invite'),
        ),
      ),
    );
  }
}

class _FakeIdentity implements CoinsIdentity {
  _FakeIdentity({this.current, this.signInResult});

  @override
  CoinsUser? current;

  CoinsSignInResult? signInResult;
  var signInCalls = 0;

  @override
  Future<CoinsSignInResult> signInWithGoogle() async {
    signInCalls++;
    final result =
        signInResult ?? const CoinsSignInResult.failure('not configured');
    if (result.isSuccess) {
      current = result.user;
    }
    return result;
  }
}

class _FixedCloudController extends CoinsCloudModeController {
  _FixedCloudController(this._identity, this._initial) : super(_identity) {
    state = AsyncValue.data(_initial);
  }

  final CoinsIdentity _identity;
  final CoinsCloudModeState _initial;

  @override
  Future<bool> enableCloudMode() async {
    if (_identity.current?.isGoogleIdentity != true) {
      final result = await _identity.signInWithGoogle();
      final user = result.user;
      if (user?.isGoogleIdentity != true) {
        state = AsyncValue.data(
          CoinsCloudModeState(
            mode: CoinsStorageMode.local,
            user: _identity.current,
            errorMessage: result.errorMessage,
          ),
        );
        return false;
      }
      state = AsyncValue.data(
        CoinsCloudModeState(mode: CoinsStorageMode.cloud, user: user),
      );
      return true;
    }
    state = AsyncValue.data(
      _initial.copyWith(mode: CoinsStorageMode.cloud, user: _identity.current),
    );
    return true;
  }
}
