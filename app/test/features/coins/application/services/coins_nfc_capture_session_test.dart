import 'package:airo_app/features/coins/application/services/coins_nfc_capture_session.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airo_app/core/auth/auth_service.dart';
import '../../presentation/support/vault_test_overrides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reads vault unlock state from the provider scope', (
    tester,
  ) async {
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultSessionProvider.overrideWith(TestVaultSessionNotifier.new),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(CoinsNfcCaptureSession.isVaultUnlocked(capturedRef), isTrue);
    expect(
      CoinsNfcCaptureSession.isVaultUnlockedFromContext(
        tester.element(find.byType(SizedBox)),
      ),
      isTrue,
    );
  });

  test('super-app login gate follows AuthService login flag', () async {
    SharedPreferences.setMockInitialValues({'is_logged_in': true});
    await AuthService.instance.initialize();

    expect(await CoinsNfcCaptureSession.passesSuperAppLoginGate(), isTrue);
  });
}
