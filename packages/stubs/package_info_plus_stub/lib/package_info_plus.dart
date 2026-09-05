/// Stub implementation of package_info_plus for lean TV builds.
///
/// This stub has no platform channel, so it cannot read the real
/// `versionName`/`versionCode` Gradle stamps into the APK. It reports what
/// the build *would* have stamped instead, which only stays true if these
/// values track `app/pubspec_tv.yaml` — Gradle takes `versionCode` and
/// `versionName` straight from the pubspec Flutter was pointed at.
///
/// Drift here is not cosmetic: the only consumer is `AppInfoTile`, whose
/// entire purpose is telling support which build a user is on. It reported
/// `0.0.2 (2)` against a real `0.0.7-preview+12` APK until this was fixed.
/// `app/test/core/tv_stub_version_test.dart` fails if they diverge again.
library;

/// Kept equal to the `version:` field of `app/pubspec_tv.yaml`, which is
/// `<_stubVersion>+<_stubBuildNumber>`.
const String _stubVersion = '0.0.1';
const String _stubBuildNumber = '14';

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
          appName: 'Aika Stream',
          // Matches `variantApplicationId` for the "tv" variant in
          // app/android/app/build.gradle.kts.
          packageName: 'com.developerscoffee.tv.midas',
          version: _stubVersion,
          buildNumber: _stubBuildNumber,
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
