import 'package:core_release/core_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo release matrix', () {
    test('defines current v2 profile package and entrypoint decisions', () {
      final matrix = AiroReleaseMatrix.v2Default();

      expect(matrix.validate(), isEmpty);
      expect(
        matrix.profiles.map((profile) => profile.id),
        containsAll(const [
          'iptv-standalone',
          'mobile-streaming',
          'tv',
          'ios-spm',
          'web-validation',
        ]),
      );
      expect(
        matrix.profileById('iptv-standalone').packageId,
        'io.airo.app.iptv',
      );
      expect(
        matrix.profileById('mobile-streaming').entrypoint,
        'app/lib/main_mobile_streaming.dart',
      );
      expect(matrix.profileById('tv').pubspec, 'app/pubspec_tv.yaml');
    });

    test('uses stable APK, AAB, and manifest names per profile', () {
      final tv = AiroReleaseMatrix.v2Default().profileById('tv');

      expect(
        tv.artifactFileName(
          kind: AiroReleaseArtifactKind.apk,
          version: 'v2.0.0',
        ),
        'Airo-TV-v2.0.0.apk',
      );
      expect(
        tv.artifactFileName(
          kind: AiroReleaseArtifactKind.apk,
          version: 'v2.0.0',
          abi: 'arm64-v8a',
        ),
        'Airo-TV-v2.0.0-arm64-v8a.apk',
      );
      expect(
        tv.artifactFileName(
          kind: AiroReleaseArtifactKind.playStoreAab,
          version: 'v2.0.0',
        ),
        'Airo-TV-v2.0.0-Play-Store.aab',
      );
      expect(
        tv.artifactFileName(
          kind: AiroReleaseArtifactKind.releaseManifest,
          version: 'v2.0.0',
        ),
        'Airo-TV-v2.0.0-Release-Manifest.json',
      );
      expect(
        tv.artifactFileName(
          kind: AiroReleaseArtifactKind.checksum,
          version: 'v2.0.0',
        ),
        'SHA256SUMS',
      );
    });

    test('keeps tablet support as an adaptive mobile artifact', () {
      final iptv = AiroReleaseMatrix.v2Default().profileById('iptv-standalone');

      expect(
        iptv.tabletStrategy,
        AiroReleaseTabletStrategy.adaptiveMobileArtifact,
      );
      expect(
        iptv.supportStatuses[AiroReleaseDeviceClass.androidTablet],
        AiroReleaseSupportStatus.adaptiveSupported,
      );
    });

    test('maps public, QA, Play, and deferred channel behavior', () {
      final tv = AiroReleaseMatrix.v2Default().profileById('tv');

      expect(
        tv
            .distributionFor(AiroReleaseDistributionChannel.githubRelease)
            ?.status,
        AiroReleaseDistributionStatus.required,
      );
      expect(
        tv
            .distributionFor(
              AiroReleaseDistributionChannel.firebaseAppDistribution,
            )
            ?.internalQa,
        isTrue,
      );
      expect(
        tv.distributionFor(AiroReleaseDistributionChannel.googlePlay)?.status,
        AiroReleaseDistributionStatus.pendingDecision,
      );
      expect(
        tv
            .distributionFor(AiroReleaseDistributionChannel.amazonAppstore)
            ?.status,
        AiroReleaseDistributionStatus.deferred,
      );
      expect(
        tv.distributionFor(AiroReleaseDistributionChannel.fDroid)?.status,
        AiroReleaseDistributionStatus.deferred,
      );
      expect(
        tv.distributionFor(AiroReleaseDistributionChannel.directApk)?.status,
        AiroReleaseDistributionStatus.pendingDecision,
      );
    });

    test('documents unsupported and deferred platforms explicitly', () {
      final matrix = AiroReleaseMatrix.v2Default();

      expect(
        matrix.profileById('tv').supportStatuses[AiroReleaseDeviceClass.fireTv],
        AiroReleaseSupportStatus.compatibleExperimental,
      );
      expect(
        matrix
            .profileById('ios-spm')
            .supportStatuses[AiroReleaseDeviceClass.iosIpadOs],
        AiroReleaseSupportStatus.deferred,
      );
      expect(
        matrix
            .profileById('web-validation')
            .supportStatuses[AiroReleaseDeviceClass.web],
        AiroReleaseSupportStatus.validationOnly,
      );
    });

    test('validation catches duplicate profile and package IDs', () {
      final source = AiroReleaseMatrix.v2Default().profileById('tv');
      final invalid = AiroReleaseMatrix(profiles: [source, source]);

      final codes = invalid.validate().map((finding) => finding.code).toSet();

      expect(codes, contains(AiroReleaseValidationCode.duplicateProfileId));
      expect(codes, contains(AiroReleaseValidationCode.duplicatePackageId));
    });

    test('public maps omit private signing and debug material', () {
      final publicMap = AiroReleaseMatrix.v2Default().toPublicMap().toString();

      expect(publicMap, contains('io.airo.app.tv'));
      expect(publicMap, isNot(contains('keystore')));
      expect(publicMap, isNot(contains('signing')));
      expect(
        publicMap,
        isNot(
          contains(
            'pass'
            'word',
          ),
        ),
      );
      expect(
        publicMap,
        isNot(
          contains(
            'api'
            '_key',
          ),
        ),
      );
      expect(publicMap, isNot(contains('/Users/')));
    });
  });
}
