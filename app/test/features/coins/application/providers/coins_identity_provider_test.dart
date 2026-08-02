import 'package:airo_app/core/auth/auth_service.dart';
import 'package:airo_app/features/coins/application/providers/coins_identity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'maps the current super-app user into the narrow coins identity',
    () async {
      final createdAt = DateTime(2026, 7, 29);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'current_user',
        '{"id":"coins-user","username":"Ada","email":"ada@example.com",'
            '"isAdmin":false,"isGoogleUser":true,'
            '"createdAt":"${createdAt.toIso8601String()}"}',
      );
      await prefs.setBool('is_logged_in', true);
      await AuthService.instance.initialize();

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final identity = container.read(coinsIdentityProvider);

      expect(identity, isA<AuthServiceCoinsIdentity>());
      expect(identity.current?.id, 'coins-user');
      expect(identity.current?.username, 'Ada');
      expect(identity.current?.email, 'ada@example.com');
      expect(identity.current?.isGoogleIdentity, isTrue);
    },
  );

  test('maps a missing super-app user to no coins identity', () async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.initialize();

    expect(const AuthServiceCoinsIdentity().current, isNull);
  });
}
