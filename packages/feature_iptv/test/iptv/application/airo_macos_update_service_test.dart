import 'package:feature_iptv/application/services/airo_macos_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroMacosUpdateService', () {
    test('detects a newer release with a macOS zip asset', () {
      final result = AiroMacosUpdateService.parseLatestReleasePayload(
        _releasePayload(
          tagName: 'airo-tv-v2.0.1',
          assetName: 'Airo-TV-2.0.1-macOS.zip',
        ),
        currentVersion: '2.0.0',
      );

      expect(result.availability, AiroMacosUpdateAvailability.available);
      expect(result.latestVersion, '2.0.1');
      expect(result.releaseUrl.toString(), contains('/releases/tag/'));
      expect(result.assetUrl.toString(), endsWith('Airo-TV-2.0.1-macOS.zip'));
    });

    test('does not offer newer releases without a macOS asset', () {
      final result = AiroMacosUpdateService.parseLatestReleasePayload(
        _releasePayload(
          tagName: 'airo-tv-v2.0.1',
          assetName: 'Airo-TV-2.0.1-android.apk',
        ),
        currentVersion: '2.0.0',
      );

      expect(result.availability, AiroMacosUpdateAvailability.unavailable);
      expect(result.latestVersion, '2.0.1');
      expect(result.assetUrl, isNull);
      expect(result.detail, contains('macOS app'));
    });

    test('reports up to date when the macOS asset is not newer', () {
      final result = AiroMacosUpdateService.parseLatestReleasePayload(
        _releasePayload(
          tagName: 'airo-tv-v2.0.0',
          assetName: 'Airo-TV-2.0.0-macOS.dmg',
        ),
        currentVersion: '2.0.0',
      );

      expect(result.availability, AiroMacosUpdateAvailability.upToDate);
      expect(result.latestVersion, '2.0.0');
      expect(result.assetUrl.toString(), endsWith('Airo-TV-2.0.0-macOS.dmg'));
    });

    test('extracts release version from macOS asset names', () {
      final result = AiroMacosUpdateService.parseLatestReleasePayload(
        _releasePayload(
          tagName: 'macos-release-candidate',
          releaseName: 'Airo TV desktop',
          assetName: 'Airo-TV-2.1.0-macOS.zip',
        ),
        currentVersion: '2.0.9',
      );

      expect(result.availability, AiroMacosUpdateAvailability.available);
      expect(result.latestVersion, '2.1.0');
    });
  });
}

Map<String, dynamic> _releasePayload({
  required String tagName,
  required String assetName,
  String? releaseName,
}) {
  return {
    'tag_name': tagName,
    'name': releaseName ?? tagName,
    'html_url':
        'https://github.com/DevelopersCoffee/airo/releases/tag/$tagName',
    'assets': [
      {
        'name': assetName,
        'browser_download_url':
            'https://github.com/DevelopersCoffee/airo/releases/download/$tagName/$assetName',
      },
    ],
  };
}
