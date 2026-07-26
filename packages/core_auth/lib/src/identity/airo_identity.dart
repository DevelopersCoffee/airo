enum AiroIdentityProviderKind {
  anonymous,
  qrPairing,
  google,
  apple,
  lan,
  enterprise,
}

enum AiroIdentityStatus { authenticated, cancelled, unavailable, rejected }

class AiroIdentityPrincipal {
  const AiroIdentityPrincipal({
    required this.subjectId,
    required this.provider,
    required this.authenticatedAt,
    this.displayName,
    this.email,
  }) : assert(subjectId != '');

  final String subjectId;
  final AiroIdentityProviderKind provider;
  final DateTime authenticatedAt;
  final String? displayName;
  final String? email;

  @override
  String toString() => 'AiroIdentityPrincipal(${provider.name}, redacted)';
}

class AiroIdentityResult {
  const AiroIdentityResult._(this.status, this.principal, this.reasonCode);

  factory AiroIdentityResult.authenticated(AiroIdentityPrincipal principal) =>
      AiroIdentityResult._(AiroIdentityStatus.authenticated, principal, null);

  const AiroIdentityResult.cancelled()
    : this._(AiroIdentityStatus.cancelled, null, 'cancelled');

  const AiroIdentityResult.unavailable()
    : this._(AiroIdentityStatus.unavailable, null, 'unavailable');

  const AiroIdentityResult.rejected(String reasonCode)
    : this._(AiroIdentityStatus.rejected, null, reasonCode);

  final AiroIdentityStatus status;
  final AiroIdentityPrincipal? principal;
  final String? reasonCode;

  bool get isAuthenticated =>
      status == AiroIdentityStatus.authenticated && principal != null;
}

class AiroIdentityRequest {
  const AiroIdentityRequest({
    required this.provider,
    this.preferSilent = false,
    this.qrClaim,
  });

  final AiroIdentityProviderKind provider;
  final bool preferSilent;
  final AiroQrIdentityClaim? qrClaim;
}

abstract interface class AiroIdentityProvider {
  AiroIdentityProviderKind get kind;

  Future<bool> isAvailable();

  Future<AiroIdentityResult> authenticate(AiroIdentityRequest request);

  Future<void> signOut();
}

abstract interface class AiroIdentity {
  AiroIdentityPrincipal? get currentPrincipal;

  Future<AiroIdentityResult> authenticate(AiroIdentityRequest request);

  Future<void> signOut();
}

class AiroIdentityCoordinator implements AiroIdentity {
  AiroIdentityCoordinator({
    required AiroAnonymousIdentityProvider anonymousProvider,
    Iterable<AiroIdentityProvider> providers = const [],
  }) : _anonymousProvider = anonymousProvider,
       _providers = {
         anonymousProvider.kind: anonymousProvider,
         for (final provider in providers) provider.kind: provider,
       };

  final AiroAnonymousIdentityProvider _anonymousProvider;
  final Map<AiroIdentityProviderKind, AiroIdentityProvider> _providers;
  AiroIdentityPrincipal? _currentPrincipal;

  @override
  AiroIdentityPrincipal? get currentPrincipal => _currentPrincipal;

  Future<AiroIdentityResult> authenticateDefault() => authenticate(
    const AiroIdentityRequest(provider: AiroIdentityProviderKind.anonymous),
  );

  @override
  Future<AiroIdentityResult> authenticate(AiroIdentityRequest request) async {
    final provider = _providers[request.provider];
    if (provider == null) {
      return const AiroIdentityResult.unavailable();
    }
    if (!await provider.isAvailable()) {
      return const AiroIdentityResult.unavailable();
    }
    final result = await provider.authenticate(request);
    if (result.isAuthenticated) _currentPrincipal = result.principal;
    return result;
  }

  @override
  Future<void> signOut() async {
    final principal = _currentPrincipal;
    _currentPrincipal = null;
    if (principal == null) return;
    await _providers[principal.provider]?.signOut();
    if (principal.provider != AiroIdentityProviderKind.anonymous) {
      await _anonymousProvider.signOut();
    }
  }
}

class AiroAnonymousIdentityProvider implements AiroIdentityProvider {
  AiroAnonymousIdentityProvider({
    required String deviceSubjectId,
    DateTime Function()? clock,
  }) : _deviceSubjectId = deviceSubjectId.trim(),
       _clock = clock ?? DateTime.now {
    if (_deviceSubjectId.isEmpty) {
      throw ArgumentError.value(
        deviceSubjectId,
        'deviceSubjectId',
        'must not be empty',
      );
    }
  }

  final String _deviceSubjectId;
  final DateTime Function() _clock;

  @override
  AiroIdentityProviderKind get kind => AiroIdentityProviderKind.anonymous;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<AiroIdentityResult> authenticate(AiroIdentityRequest request) async {
    return AiroIdentityResult.authenticated(
      AiroIdentityPrincipal(
        subjectId: _deviceSubjectId,
        provider: kind,
        authenticatedAt: _clock().toUtc(),
      ),
    );
  }

  @override
  Future<void> signOut() async {}
}

class AiroQrIdentityClaim {
  const AiroQrIdentityClaim({
    required this.pairingSessionId,
    required this.signedClaim,
  });

  final String pairingSessionId;
  final String signedClaim;

  @override
  String toString() => 'AiroQrIdentityClaim(redacted)';
}

class AiroExternalIdentityClaim {
  const AiroExternalIdentityClaim({
    required this.subjectId,
    this.displayName,
    this.email,
  });

  final String subjectId;
  final String? displayName;
  final String? email;
}

typedef AiroQrClaimVerifier =
    Future<AiroExternalIdentityClaim?> Function(AiroQrIdentityClaim claim);

class AiroQrIdentityProvider implements AiroIdentityProvider {
  AiroQrIdentityProvider({
    required AiroQrClaimVerifier verifyClaim,
    DateTime Function()? clock,
  }) : // Keep the public callback label independent of the private field.
       // ignore: prefer_initializing_formals
       _verifyClaim = verifyClaim,
       _clock = clock ?? DateTime.now;

  final AiroQrClaimVerifier _verifyClaim;
  final DateTime Function() _clock;

  @override
  AiroIdentityProviderKind get kind => AiroIdentityProviderKind.qrPairing;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<AiroIdentityResult> authenticate(AiroIdentityRequest request) async {
    final claim = request.qrClaim;
    if (claim == null) {
      return const AiroIdentityResult.rejected('missing_qr_claim');
    }
    final verified = await _verifyClaim(claim);
    if (verified == null || verified.subjectId.trim().isEmpty) {
      return const AiroIdentityResult.rejected('invalid_qr_claim');
    }
    return AiroIdentityResult.authenticated(
      _principalFromClaim(verified, kind, _clock()),
    );
  }

  @override
  Future<void> signOut() async {}
}

typedef AiroGoogleClaimLoader =
    Future<AiroExternalIdentityClaim?> Function({required bool silent});
typedef AiroIdentityAvailability = Future<bool> Function();
typedef AiroIdentitySignOut = Future<void> Function();

class AiroGoogleIdentityProvider implements AiroIdentityProvider {
  AiroGoogleIdentityProvider({
    required AiroGoogleClaimLoader loadClaim,
    required AiroIdentityAvailability isProviderAvailable,
    required AiroIdentitySignOut signOutProvider,
    DateTime Function()? clock,
  }) : // Keep provider-facing labels independent of private field names.
       // ignore: prefer_initializing_formals
       _loadClaim = loadClaim,
       // ignore: prefer_initializing_formals
       _isProviderAvailable = isProviderAvailable,
       // ignore: prefer_initializing_formals
       _signOutProvider = signOutProvider,
       _clock = clock ?? DateTime.now;

  final AiroGoogleClaimLoader _loadClaim;
  final AiroIdentityAvailability _isProviderAvailable;
  final AiroIdentitySignOut _signOutProvider;
  final DateTime Function() _clock;

  @override
  AiroIdentityProviderKind get kind => AiroIdentityProviderKind.google;

  @override
  Future<bool> isAvailable() => _isProviderAvailable();

  @override
  Future<AiroIdentityResult> authenticate(AiroIdentityRequest request) async {
    final claim = await _loadClaim(silent: request.preferSilent);
    if (claim == null) return const AiroIdentityResult.cancelled();
    if (claim.subjectId.trim().isEmpty) {
      return const AiroIdentityResult.rejected('invalid_provider_subject');
    }
    return AiroIdentityResult.authenticated(
      _principalFromClaim(claim, kind, _clock()),
    );
  }

  @override
  Future<void> signOut() => _signOutProvider();
}

AiroIdentityPrincipal _principalFromClaim(
  AiroExternalIdentityClaim claim,
  AiroIdentityProviderKind provider,
  DateTime authenticatedAt,
) {
  return AiroIdentityPrincipal(
    subjectId: claim.subjectId.trim(),
    provider: provider,
    authenticatedAt: authenticatedAt.toUtc(),
    displayName: claim.displayName,
    email: claim.email,
  );
}
