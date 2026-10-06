import 'package:airo_app/core/coins/coins_standalone_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standalone identity stays local-only', () async {
    const identity = LocalCoinsIdentity();

    expect(identity.current, isNull);

    final result = await identity.signInWithGoogle();
    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, contains('standalone Airo Coin'));
  });
}
