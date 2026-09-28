import '../core/license.dart';
import '../exceptions/license_exception.dart';

/// Hosted API port. OSS uses [LocalLicenseClient] and never opens a socket.
abstract interface class LicenseClient {
  Future<LicenseSnapshot> initialize({
    required String productId,
    required String installationId,
    String? publicKey,
    String? platform,
    String? deviceType,
    String? appVersion,
  });

  Future<LicenseSnapshot> status({required String installationId});
}

/// Creates or returns a process-local free license. Repeated initialize for
/// the same installation id does not allocate a new license.
class LocalLicenseClient implements LicenseClient {
  final Map<String, LicenseSnapshot> _byInstallation = {};

  @override
  Future<LicenseSnapshot> initialize({
    required String productId,
    required String installationId,
    String? publicKey,
    String? platform,
    String? deviceType,
    String? appVersion,
  }) async {
    final existing = _byInstallation[installationId];
    if (existing != null) return existing;
    final snapshot = LicenseSnapshot(
      licenseId: 'lic_local_$installationId',
      productId: productId,
      installationId: installationId,
      issuedAt: DateTime.now().toUtc(),
    );
    _byInstallation[installationId] = snapshot;
    return snapshot;
  }

  @override
  Future<LicenseSnapshot> status({required String installationId}) async {
    final existing = _byInstallation[installationId];
    if (existing == null) {
      throw LicenseException(
        LicenseErrorCode.invalidSnapshot,
        'No local license for this installation.',
      );
    }
    return existing;
  }
}
