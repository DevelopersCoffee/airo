import 'dart:io';
import 'package:crypto/crypto.dart';
import '../contracts/integrity_verifier.dart';

class CryptoIntegrityVerifier implements IntegrityVerifier {
  @override
  Future<IntegrityResult> verifySha256(File file, String expectedHash) async {
    if (!await file.exists()) {
      return IntegrityResult(isValid: false, expectedHash: expectedHash, actualHash: 'file_not_found');
    }

    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    final actualHash = digest.toString();

    return IntegrityResult(
      isValid: actualHash.toLowerCase() == expectedHash.toLowerCase(),
      expectedHash: expectedHash.toLowerCase(),
      actualHash: actualHash.toLowerCase(),
    );
  }
}
