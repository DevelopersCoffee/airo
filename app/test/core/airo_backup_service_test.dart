import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/core/portability/airo_backup_service.dart';

void main() {
  test('encrypted backup round-trips and rejects a wrong passphrase', () async {
    final service = AiroBackupService();
    const payload = <String, Object?>{
      'scope': 'airo-mind',
      'models': ['gemma-4b'],
    };

    final encoded = await service.encrypt(payload, 'correct horse battery');
    expect(encoded, isNot(contains('gemma-4b')));
    final decoded = await service.decrypt(encoded, 'correct horse battery');
    expect(decoded['scope'], 'airo-mind');
    expect(decoded['models'], ['gemma-4b']);
    expect(
      () => service.decrypt(encoded, 'wrong passphrase'),
      throwsA(isA<FormatException>()),
    );
  });
}
