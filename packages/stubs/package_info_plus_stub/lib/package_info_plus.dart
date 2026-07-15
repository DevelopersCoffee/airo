/// Stub implementation of package_info_plus for lean TV builds.
library;

class PackageInfo {
  PackageInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
    this.buildSignature = '',
    this.installerStore,
    this.installTime,
    this.updateTime,
  });

  static PackageInfo? _fromPlatform;

  static Future<PackageInfo> fromPlatform({String? baseUrl}) async {
    return _fromPlatform ??
        PackageInfo(
          appName: 'Airo TV',
          packageName: 'io.airo.app.tv',
          version: '0.0.2',
          buildNumber: '2',
        );
  }

  static void setMockInitialValues({
    required String appName,
    required String packageName,
    required String version,
    required String buildNumber,
    required String buildSignature,
    String? installerStore,
    DateTime? installTime,
    DateTime? updateTime,
  }) {
    _fromPlatform = PackageInfo(
      appName: appName,
      packageName: packageName,
      version: version,
      buildNumber: buildNumber,
      buildSignature: buildSignature,
      installerStore: installerStore,
      installTime: installTime,
      updateTime: updateTime,
    );
  }

  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;
  final String buildSignature;
  final String? installerStore;
  final DateTime? installTime;
  final DateTime? updateTime;
}
