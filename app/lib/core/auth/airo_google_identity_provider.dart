import 'package:core_auth/core_auth.dart';

import 'google_auth_service.dart';

/// The only adapter allowed to translate Google/Firebase-backed app results
/// into the provider-neutral core identity contract.
AiroGoogleIdentityProvider createAiroGoogleIdentityProvider({
  GoogleAuthService? service,
}) {
  final google = service ?? GoogleAuthService.instance;
  return AiroGoogleIdentityProvider(
    isProviderAvailable: google.isGoogleSignInAvailable,
    signOutProvider: google.signOut,
    loadClaim: ({required silent}) async {
      final result = silent
          ? await google.signInSilently()
          : await google.signInWithGoogle();
      final user = result?.user;
      if (result == null || !result.success || user == null) return null;
      return AiroExternalIdentityClaim(
        subjectId: user.id,
        displayName: user.username,
        email: user.email,
      );
    },
  );
}
