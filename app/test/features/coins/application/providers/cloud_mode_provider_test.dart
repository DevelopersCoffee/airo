import 'package:airo_app/features/coins/application/providers/cloud_mode_provider.dart';
import 'package:airo_app/features/coins/application/providers/coins_identity_provider.dart';
import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the super-app's auth singletons. Before the CoinsIdentity
/// contract existed this controller reached AuthService.instance directly
/// and could not be tested at all.
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
        signInResult ?? const CoinsSignInResult.failure('no result configured');
    if (result.isSuccess) current = result.user;
    return result;
  }
}

const _googleUser = CoinsUser(
  id: 'u-1',
  email: 'a@example.com',
  username: 'ada',
  isGoogleIdentity: true,
);

ProviderContainer _containerWith(_FakeIdentity identity) {
  final container = ProviderContainer(
    overrides: [coinsIdentityProvider.overrideWithValue(identity)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<CoinsCloudModeState> _settled(ProviderContainer container) async {
  for (var i = 0; i < 20; i++) {
    final value = container.read(coinsCloudModeControllerProvider).value;
    if (value != null) return value;
    await Future<void>.delayed(Duration.zero);
  }
  fail('cloud mode state never resolved');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a local-only identity cannot sit in cloud mode', () async {
    SharedPreferences.setMockInitialValues({
      'coins_storage_mode': CoinsStorageMode.cloud.name,
    });
    final identity = _FakeIdentity(
      current: const CoinsUser(
        id: 'u-2',
        username: 'local',
        isGoogleIdentity: false,
      ),
    );

    final state = await _settled(_containerWith(identity));

    // Cloud sync needs a Google identity, so a stored cloud preference must
    // not be honoured for a local account.
    expect(state.mode, CoinsStorageMode.local);
    expect(state.hasGoogleIdentity, isFalse);
  });

  test(
    'enabling cloud mode signs in when the identity is not Google',
    () async {
      final identity = _FakeIdentity(
        signInResult: const CoinsSignInResult.success(_googleUser),
      );
      final container = _containerWith(identity);
      await _settled(container);

      final enabled = await container
          .read(coinsCloudModeControllerProvider.notifier)
          .enableCloudMode();

      expect(enabled, isTrue);
      expect(identity.signInCalls, 1);
      final state = container.read(coinsCloudModeControllerProvider).value!;
      expect(state.mode, CoinsStorageMode.cloud);
      expect(state.userLabel, 'a@example.com');
    },
  );

  test(
    'a refused sign-in leaves the vault in local mode with a reason',
    () async {
      final identity = _FakeIdentity(
        signInResult: const CoinsSignInResult.failure('user cancelled'),
      );
      final container = _containerWith(identity);
      await _settled(container);

      final enabled = await container
          .read(coinsCloudModeControllerProvider.notifier)
          .enableCloudMode();

      expect(enabled, isFalse);
      final state = container.read(coinsCloudModeControllerProvider).value!;
      expect(state.mode, CoinsStorageMode.local);
      expect(state.errorMessage, 'user cancelled');
    },
  );

  test('a non-Google sign-in result cannot enable cloud mode', () async {
    final identity = _FakeIdentity(
      signInResult: const CoinsSignInResult.success(
        CoinsUser(id: 'local-user', isGoogleIdentity: false, username: 'local'),
      ),
    );
    final container = _containerWith(identity);
    await _settled(container);

    final enabled = await container
        .read(coinsCloudModeControllerProvider.notifier)
        .enableCloudMode();

    expect(enabled, isFalse);
    final state = container.read(coinsCloudModeControllerProvider).value!;
    expect(state.mode, CoinsStorageMode.local);
    expect(state.hasGoogleIdentity, isFalse);
    expect(state.errorMessage, 'A Google identity is required');
  });

  test(
    'an already-Google identity enables cloud mode without a new sign-in',
    () async {
      final identity = _FakeIdentity(current: _googleUser);
      final container = _containerWith(identity);
      await _settled(container);

      final enabled = await container
          .read(coinsCloudModeControllerProvider.notifier)
          .enableCloudMode();

      expect(enabled, isTrue);
      expect(identity.signInCalls, 0);
    },
  );
}
