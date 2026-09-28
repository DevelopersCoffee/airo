import '../core/license.dart';

abstract interface class LicenseCache {
  Future<LicenseSnapshot?> read();
  Future<void> write(LicenseSnapshot snapshot);
}

class MemoryLicenseCache implements LicenseCache {
  LicenseSnapshot? _snapshot;

  @override
  Future<LicenseSnapshot?> read() async => _snapshot;

  @override
  Future<void> write(LicenseSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}
