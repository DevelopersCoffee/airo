import 'dart:io';

class IntegrityResult {
  final bool isValid;
  final String expectedHash;
  final String actualHash;

  const IntegrityResult({
    required this.isValid,
    required this.expectedHash,
    required this.actualHash,
  });
}

abstract interface class IntegrityVerifier {
  Future<IntegrityResult> verifySha256(File file, String expectedHash);
}
