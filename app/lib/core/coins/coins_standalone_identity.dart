import 'package:feature_coins_core/feature_coins_core.dart';

/// Local-only identity for the standalone Airo Coin shell.
///
/// Shared expenses use the `local_user` creator id when cloud mode is off;
/// this implementation keeps cloud sign-in unavailable so the splits loop
/// stays on-device without pulling super-app auth singletons.
class LocalCoinsIdentity implements CoinsIdentity {
  const LocalCoinsIdentity();

  @override
  CoinsUser? get current => null;

  @override
  Future<CoinsSignInResult> signInWithGoogle() async {
    return const CoinsSignInResult.failure(
      'Cloud sync is not available in the standalone Airo Coin app.',
    );
  }
}
