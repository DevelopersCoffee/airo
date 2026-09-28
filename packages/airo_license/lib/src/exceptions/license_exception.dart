/// Typed failure from the license SDK. Transport failure is never revocation.
class LicenseException implements Exception {
  LicenseException(this.code, this.message);

  factory LicenseException.purchasesUnavailable() => LicenseException(
    LicenseErrorCode.purchasesUnavailable,
    'Purchases are not available in this build.',
  );

  factory LicenseException.stub(String feature) => LicenseException(
    LicenseErrorCode.notImplemented,
    '$feature is not implemented in the local-first SDK.',
  );

  factory LicenseException.network() => LicenseException(
    LicenseErrorCode.networkUnavailable,
    'The hosted license API is not used by this client.',
  );

  final LicenseErrorCode code;
  final String message;

  @override
  String toString() => 'LicenseException(${code.name}): $message';
}

enum LicenseErrorCode {
  purchasesUnavailable,
  notImplemented,
  networkUnavailable,
  invalidSnapshot,
  revoked,
  deviceLimit,
  expired,
}
