import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/auth/google_auth_service.dart';

enum CoinsStorageMode { local, cloud }

class CoinsCloudModeState {
  final CoinsStorageMode mode;
  final User? user;
  final String? errorMessage;

  const CoinsCloudModeState({required this.mode, this.user, this.errorMessage});

  bool get isCloudMode => mode == CoinsStorageMode.cloud;

  bool get hasGoogleIdentity => user?.isGoogleUser == true;

  String get userLabel => user?.email ?? user?.username ?? 'Not signed in';

  CoinsCloudModeState copyWith({
    CoinsStorageMode? mode,
    User? user,
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
    >((ref) => CoinsCloudModeController());

class CoinsCloudModeController
    extends StateNotifier<AsyncValue<CoinsCloudModeState>> {
  CoinsCloudModeController() : super(const AsyncValue.loading()) {
    _load();
  }

  static const String _modeKey = 'coins_storage_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeName = prefs.getString(_modeKey);
    final mode = modeName == CoinsStorageMode.cloud.name
        ? CoinsStorageMode.cloud
        : CoinsStorageMode.local;
    final user = AuthService.instance.currentUser;
    state = AsyncValue.data(
      CoinsCloudModeState(
        mode: user?.isGoogleUser == true ? mode : CoinsStorageMode.local,
        user: user,
      ),
    );
  }

  Future<bool> enableCloudMode() async {
    state = const AsyncValue.loading();
    try {
      var user = AuthService.instance.currentUser;
      if (user?.isGoogleUser != true) {
        final result = await GoogleAuthService.instance.signInWithGoogle();
        if (!result.success || result.user == null) {
          state = AsyncValue.data(
            CoinsCloudModeState(
              mode: CoinsStorageMode.local,
              user: AuthService.instance.currentUser,
              errorMessage: result.message ?? 'Google sign-in failed',
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
        user: AuthService.instance.currentUser,
      ),
    );
  }

  Future<void> refresh() => _load();
}
