import 'package:core_auth/core_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 27, 12);

  test(
    'anonymous identity is stable and requires no external callback',
    () async {
      final provider = AiroAnonymousIdentityProvider(
        deviceSubjectId: 'device:opaque-1',
        clock: () => now,
      );

      final first = await provider.authenticate(
        const AiroIdentityRequest(provider: AiroIdentityProviderKind.anonymous),
      );
      final second = await provider.authenticate(
        const AiroIdentityRequest(provider: AiroIdentityProviderKind.anonymous),
      );

      expect(first.principal!.subjectId, 'device:opaque-1');
      expect(second.principal!.subjectId, first.principal!.subjectId);
      expect(first.principal.toString(), contains('redacted'));
    },
  );

  test('QR identity accepts only verifier-approved opaque claims', () async {
    final provider = AiroQrIdentityProvider(
      clock: () => now,
      verifyClaim: (claim) async => claim.signedClaim == 'valid-signature'
          ? const AiroExternalIdentityClaim(subjectId: 'paired:opaque-2')
          : null,
    );

    final rejected = await provider.authenticate(
      const AiroIdentityRequest(
        provider: AiroIdentityProviderKind.qrPairing,
        qrClaim: AiroQrIdentityClaim(
          pairingSessionId: 'session',
          signedClaim: 'bad',
        ),
      ),
    );
    final accepted = await provider.authenticate(
      const AiroIdentityRequest(
        provider: AiroIdentityProviderKind.qrPairing,
        qrClaim: AiroQrIdentityClaim(
          pairingSessionId: 'session',
          signedClaim: 'valid-signature',
        ),
      ),
    );

    expect(rejected.reasonCode, 'invalid_qr_claim');
    expect(accepted.principal!.subjectId, 'paired:opaque-2');
    expect(accepted.principal!.provider, AiroIdentityProviderKind.qrPairing);
  });

  test(
    'Google identity distinguishes silent and interactive requests',
    () async {
      final silentValues = <bool>[];
      var signOutCalls = 0;
      final provider = AiroGoogleIdentityProvider(
        clock: () => now,
        isProviderAvailable: () async => true,
        signOutProvider: () async => signOutCalls++,
        loadClaim: ({required silent}) async {
          silentValues.add(silent);
          if (silent) return null;
          return const AiroExternalIdentityClaim(
            subjectId: 'google:opaque-3',
            displayName: 'Viewer',
          );
        },
      );

      final silent = await provider.authenticate(
        const AiroIdentityRequest(
          provider: AiroIdentityProviderKind.google,
          preferSilent: true,
        ),
      );
      final interactive = await provider.authenticate(
        const AiroIdentityRequest(provider: AiroIdentityProviderKind.google),
      );
      await provider.signOut();

      expect(silent.status, AiroIdentityStatus.cancelled);
      expect(interactive.principal!.subjectId, 'google:opaque-3');
      expect(silentValues, [true, false]);
      expect(signOutCalls, 1);
    },
  );

  test(
    'coordinator defaults anonymous and never silently falls back',
    () async {
      final anonymous = AiroAnonymousIdentityProvider(
        deviceSubjectId: 'device:default',
        clock: () => now,
      );
      final coordinator = AiroIdentityCoordinator(anonymousProvider: anonymous);

      final initial = await coordinator.authenticateDefault();
      final unavailable = await coordinator.authenticate(
        const AiroIdentityRequest(provider: AiroIdentityProviderKind.apple),
      );

      expect(initial.principal!.provider, AiroIdentityProviderKind.anonymous);
      expect(unavailable.status, AiroIdentityStatus.unavailable);
      expect(
        coordinator.currentPrincipal!.provider,
        AiroIdentityProviderKind.anonymous,
      );
    },
  );
}
