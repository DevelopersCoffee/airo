import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coins_identity_provider.dart';

enum CoinsStorageMode { local, cloud }

class CoinsCloudModeState {
  final CoinsStorageMode mode;
  final CoinsUser? user;
  final String? errorMessage;

  const CoinsCloudModeState({required this.mode, this.user, this.errorMessage});

  bool get isCloudMode => mode == CoinsStorageMode.cloud;

  bool get hasGoogleIdentity => user?.isGoogleIdentity == true;

  String get userLabel => user?.label ?? 'Not signed in';

  CoinsCloudModeState copyWith({
    CoinsStorageMode? mode,
    CoinsUser? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CoinsCloudModeState(
      mode: mode ?? this.mode,
      user: user ?? this.user,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final coinsCloudModeControllerProvider =
    StateNotifierProvider<
      CoinsCloudModeController,
      AsyncValue<CoinsCloudModeState>
    >((ref) => CoinsCloudModeController(ref.watch(coinsIdentityProvider)));

class CoinsCloudModeController
    extends StateNotifier<AsyncValue<CoinsCloudModeState>> {
  CoinsCloudModeController(this._identity) : super(const AsyncValue.loading()) {
    _load();
  }

  final CoinsIdentity _identity;

  static const String _modeKey = 'coins_storage_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeName = prefs.getString(_modeKey);
    final mode = modeName == CoinsStorageMode.cloud.name
        ? CoinsStorageMode.cloud
        : CoinsStorageMode.local;
    final user = _identity.current;
    state = AsyncValue.data(
      CoinsCloudModeState(
        mode: user?.isGoogleIdentity == true ? mode : CoinsStorageMode.local,
        user: user,
      ),
    );
  }

  Future<bool> enableCloudMode() async {
    state = const AsyncValue.loading();
    try {
      var user = _identity.current;
      if (user?.isGoogleIdentity != true) {
        final result = await _identity.signInWithGoogle();
        if (!result.isSuccess) {
          state = AsyncValue.data(
            CoinsCloudModeState(
              mode: CoinsStorageMode.local,
              user: _identity.current,
              errorMessage: result.errorMessage ?? 'Google sign-in failed',
            ),
          );
          return false;
        }
        user = result.user;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, CoinsStorageMode.cloud.name);
      state = AsyncValue.data(
        CoinsCloudModeState(mode: CoinsStorageMode.cloud, user: user),
      );
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> useLocalMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, CoinsStorageMode.local.name);
    state = AsyncValue.data(
      CoinsCloudModeState(
        mode: CoinsStorageMode.local,
        user: _identity.current,
      ),
    );
  }

  Future<void> refresh() => _load();
}
