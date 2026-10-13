import 'package:airo_app/features/coins/application/services/coins_nfc_capture_platform.dart';
import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('matches capture deep links with and without scheme', () {
    expect(
      CoinsNfcCapturePlatform.routeMatchesCaptureDeepLink(
        NfcExpenseCaptureLink.path,
      ),
      isTrue,
    );
    expect(
      CoinsNfcCapturePlatform.routeMatchesCaptureDeepLink(
        'airo://coins${NfcExpenseCaptureLink.path}',
      ),
      isTrue,
    );
    expect(
      CoinsNfcCapturePlatform.routeMatchesCaptureDeepLink('/money/dashboard'),
      isFalse,
    );
  });

  test('returns false for pending capture on non-Android test hosts', () async {
    expect(await CoinsNfcCapturePlatform.hasPendingCaptureLaunch(), isFalse);
    expect(
      await CoinsNfcCapturePlatform.consumePendingCaptureLaunch(),
      isFalse,
    );
  });
}
