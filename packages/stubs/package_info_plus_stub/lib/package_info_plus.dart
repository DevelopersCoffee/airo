library;

class PackageInfo {
  const PackageInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
    this.buildSignature = '',
    this.installerStore,
  });

  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;
  final String buildSignature;
  final String? installerStore;

  static Future<PackageInfo> fromPlatform({String? baseUrl}) async {
    return const PackageInfo(
      appName: 'Airo',
      packageName: 'com.airo.app',
      version: '0.0.0',
      buildNumber: '0',
    );
  }
}
