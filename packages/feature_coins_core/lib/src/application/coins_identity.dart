/// The identity surface Airo Coins actually needs.
///
/// Coins previously reached `AuthService.instance` and
/// `GoogleAuthService.instance` directly, which tied it to the super-app's
/// auth singletons, made the cloud-mode controller untestable, and meant
/// the Coins shell could not supply its own implementation.
///
/// This is deliberately a narrow, coins-owned contract rather than a
/// dependency on an auth package: the repo currently has three competing
/// `User` types (`core_auth`, `core_domain`, and `app/lib/core/auth`), and
/// binding coins to any one of them would inherit that problem and drag
/// Flutter into this otherwise pure-Dart package. Each shell adapts
/// whatever auth it already has to these few fields.
abstract interface class CoinsIdentity {
  /// The signed-in user, or null when nobody is signed in.
  CoinsUser? get current;

  /// Starts an interactive Google sign-in.
  Future<CoinsSignInResult> signInWithGoogle();
}

/// The only user attributes coins reads.
class CoinsUser {
  const CoinsUser({
    required this.id,
    this.email,
    this.username,
    required this.isGoogleIdentity,
  });

  /// Stable identifier, used as the creator id on shared groups.
  final String id;

  final String? email;
  final String? username;

  /// Whether this identity is backed by Google, which is what cloud mode
  /// requires — a local-only account cannot sync.
  final bool isGoogleIdentity;

  /// Display label for the cloud-mode UI.
  String get label => email ?? username ?? 'Not signed in';
}

/// Outcome of an interactive sign-in.
class CoinsSignInResult {
  const CoinsSignInResult.success(CoinsUser this.user) : errorMessage = null;

  const CoinsSignInResult.failure(this.errorMessage) : user = null;

  final CoinsUser? user;
  final String? errorMessage;

  bool get isSuccess => user != null;
}
