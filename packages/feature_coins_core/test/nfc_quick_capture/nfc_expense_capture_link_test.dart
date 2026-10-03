import 'package:feature_coins_core/src/nfc_quick_capture/nfc_expense_capture_link.dart';
import 'package:test/test.dart';

void main() {
  group('NfcExpenseCaptureLink', () {
    test('matches canonical airo URI', () {
      expect(
        NfcExpenseCaptureLink.matches(NfcExpenseCaptureLink.nfcExpenseCaptureUri),
        isTrue,
      );
    });

    test('matches https app link', () {
      expect(
        NfcExpenseCaptureLink.matches(NfcExpenseCaptureLink.httpsExpenseCaptureUri),
        isTrue,
      );
    });

    test('rejects unrelated URIs', () {
      expect(
        NfcExpenseCaptureLink.matches(Uri.parse('airo://coins/dashboard')),
        isFalse,
      );
      expect(
        NfcExpenseCaptureLink.matches(Uri.parse('https://example.com/')),
        isFalse,
      );
    });

    test('matchesString accepts adb-style strings', () {
      expect(
        NfcExpenseCaptureLink.matchesString('airo://coins/quick-capture'),
        isTrue,
      );
      expect(
        NfcExpenseCaptureLink.matchesString('/quick-capture'),
        isTrue,
      );
    });
  });
}
