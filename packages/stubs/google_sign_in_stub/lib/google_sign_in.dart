class GoogleSignIn {
  GoogleSignIn._();

  static final GoogleSignIn instance = GoogleSignIn._();

  Future<void> initialize({String? clientId, String? serverClientId}) async {}

  Future<GoogleSignInAccount> authenticate() async {
    throw const GoogleSignInException(
      code: GoogleSignInExceptionCode.canceled,
      description: 'Google Sign-In is unavailable in this local stub build.',
    );
  }

  Future<GoogleSignInAccount?> attemptLightweightAuthentication() async => null;

  bool supportsAuthenticate() => false;

  Future<void> signOut() async {}
}

class GoogleSignInAccount {
  GoogleSignInAccount();

  final GoogleSignInAuthorizationClient authorizationClient =
      GoogleSignInAuthorizationClient();
}

class GoogleSignInAuthorizationClient {
  Future<GoogleSignInAuthorizationResult> authorizeScopes(
    List<String> scopes,
  ) async => const GoogleSignInAuthorizationResult();
}

class GoogleSignInAuthorizationResult {
  const GoogleSignInAuthorizationResult({this.accessToken});

  final String? accessToken;
}

class GoogleSignInException implements Exception {
  const GoogleSignInException({required this.code, this.description});

  final GoogleSignInExceptionCode code;
  final String? description;

  @override
  String toString() => description == null
      ? 'GoogleSignInException($code)'
      : 'GoogleSignInException($code): $description';
}

enum GoogleSignInExceptionCode { canceled }
