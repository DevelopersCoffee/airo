import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/auth/google_auth_service.dart';

/// Adapts the super-app's auth singletons to the narrow [CoinsIdentity]
/// contract owned by `feature_coins_core`.
///
/// This is the only place coins knows that `AuthService` exists. Another
/// shell (or a test) supplies a different implementation by overriding
/// [coinsIdentityProvider].
class AuthServiceCoinsIdentity implements CoinsIdentity {
  const AuthServiceCoinsIdentity();

  @override
  CoinsUser? get current => _toCoinsUser(AuthService.instance.currentUser);

  @override
  Future<CoinsSignInResult> signInWithGoogle() async {
    final result = await GoogleAuthService.instance.signInWithGoogle();
    final user = _toCoinsUser(result.user);
    if (!result.success || user == null) {
      return CoinsSignInResult.failure(
        result.message ?? 'Google sign-in failed',
      );
    }
    return CoinsSignInResult.success(user);
  }

  CoinsUser? _toCoinsUser(User? user) {
    if (user == null) return null;
    return CoinsUser(
      id: user.id,
      email: user.email,
      username: user.username,
      isGoogleIdentity: user.isGoogleUser,
    );
  }
}

/// The identity implementation coins runs against. Overridden in tests and
/// by any shell that does not use the super-app's auth singletons.
final coinsIdentityProvider = Provider<CoinsIdentity>(
  (ref) => const AuthServiceCoinsIdentity(),
);
