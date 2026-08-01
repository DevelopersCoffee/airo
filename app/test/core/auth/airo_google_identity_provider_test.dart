import 'package:airo_app/core/auth/airo_google_identity_provider.dart';
import 'package:airo_app/core/auth/auth_service.dart';
import 'package:airo_app/core/auth/google_auth_service.dart';
import 'package:core_auth/core_auth.dart'
    show AiroIdentityProviderKind, AiroIdentityRequest, AiroIdentityStatus;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGoogleAuthService extends Mock implements GoogleAuthService {}

final _user = User(
  id: 'google-user',
  username: 'Ada',
  email: 'ada@example.com',
  isAdmin: false,
  isGoogleUser: true,
  createdAt: DateTime(2026, 7, 29),
);

void main() {
  test(
    'adapts interactive and silent Google claims without leaking provider types',
    () async {
      final service = _MockGoogleAuthService();
      when(service.isGoogleSignInAvailable).thenAnswer((_) async => true);
      when(service.signOut).thenAnswer((_) async {});
      when(
        service.signInWithGoogle,
      ).thenAnswer((_) async => AuthResult.success(_user));
      when(
        service.signInSilently,
      ).thenAnswer((_) async => AuthResult.success(_user));
      final provider = createAiroGoogleIdentityProvider(service: service);

      expect(await provider.isAvailable(), isTrue);
      final interactive = await provider.authenticate(
        const AiroIdentityRequest(provider: AiroIdentityProviderKind.google),
      );
      expect(interactive.status, AiroIdentityStatus.authenticated);
      expect(interactive.principal?.subjectId, _user.id);
      expect(interactive.principal?.displayName, _user.username);
      expect(interactive.principal?.email, _user.email);
      final silent = await provider.authenticate(
        const AiroIdentityRequest(
          provider: AiroIdentityProviderKind.google,
          preferSilent: true,
        ),
      );
      expect(silent.principal?.subjectId, _user.id);
      await provider.signOut();

      verify(service.signInWithGoogle).called(1);
      verify(service.signInSilently).called(1);
      verify(service.signOut).called(1);
    },
  );

  test('rejects unsuccessful and missing Google results', () async {
    final service = _MockGoogleAuthService();
    when(
      service.signInWithGoogle,
    ).thenAnswer((_) async => AuthResult.failure('cancelled'));
    when(service.signInSilently).thenAnswer((_) async => null);
    final provider = createAiroGoogleIdentityProvider(service: service);

    expect(
      (await provider.authenticate(
        const AiroIdentityRequest(provider: AiroIdentityProviderKind.google),
      )).status,
      AiroIdentityStatus.cancelled,
    );
    expect(
      (await provider.authenticate(
        const AiroIdentityRequest(
          provider: AiroIdentityProviderKind.google,
          preferSilent: true,
        ),
      )).status,
      AiroIdentityStatus.cancelled,
    );
  });
}
