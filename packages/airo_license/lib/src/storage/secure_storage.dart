abstract interface class LicenseSecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// Process-local store. Not a keystore; tests and OSS mock wiring only.
class MemoryLicenseSecureStorage implements LicenseSecureStorage {
  MemoryLicenseSecureStorage([Map<String, String>? seed])
    : _values = Map<String, String>.from(seed ?? const {});

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}
