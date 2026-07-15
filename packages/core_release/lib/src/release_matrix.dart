import 'package:equatable/equatable.dart';

const String kAiroReleaseMatrixSchemaVersion = '1.0.0';

enum AiroReleaseLine {
  v1('v1'),
  v2('v2');

  const AiroReleaseLine(this.stableId);

  final String stableId;
}

enum AiroReleaseDeviceClass {
  androidPhone('android_phone'),
  androidTablet('android_tablet'),
  androidTv('android_tv'),
  googleTv('google_tv'),
  fireTv('fire_tv'),
  iosIpadOs('ios_ipados'),
  web('web'),
  legacyAndroidTvBox('legacy_android_tv_box');

  const AiroReleaseDeviceClass(this.stableId);

  final String stableId;
}

enum AiroReleaseSupportStatus {
  supported('supported'),
  adaptiveSupported('adaptive_supported'),
  compatibleExperimental('compatible_experimental'),
  deferred('deferred'),
  validationOnly('validation_only'),
  unsupported('unsupported');

  const AiroReleaseSupportStatus(this.stableId);

  final String stableId;
}

enum AiroReleaseTabletStrategy {
  adaptiveMobileArtifact('adaptive_mobile_artifact'),
  separateFlavorDeferred('separate_flavor_deferred'),
  notApplicable('not_applicable');

  const AiroReleaseTabletStrategy(this.stableId);

  final String stableId;
}

enum AiroReleaseAbiStrategy {
  singleArm64Apk('single_arm64_apk'),
  universalApk('universal_apk'),
  splitByAbi('split_by_abi'),
  notApplicable('not_applicable');

  const AiroReleaseAbiStrategy(this.stableId);

  final String stableId;
}

enum AiroReleaseArtifactKind {
  apk('apk'),
  playStoreAab('play_store_aab'),
  releaseManifest('release_manifest'),
  checksum('checksum'),
  releaseNotes('release_notes'),
  sourceArchive('source_archive'),
  debugSymbols('debug_symbols'),
  storeMedia('store_media');

  const AiroReleaseArtifactKind(this.stableId);

  final String stableId;
}

enum AiroReleaseDistributionChannel {
  githubRelease('github_release'),
  firebaseAppDistribution('firebase_app_distribution'),
  googlePlay('google_play'),
  amazonAppstore('amazon_appstore'),
  fDroid('fdroid'),
  directApk('direct_apk'),
  localValidation('local_validation');

  const AiroReleaseDistributionChannel(this.stableId);

  final String stableId;
}

enum AiroReleaseDistributionStatus {
  required('required'),
  optional('optional'),
  pendingCredentials('pending_credentials'),
  pendingDecision('pending_decision'),
  deferred('deferred'),
  validationOnly('validation_only'),
  unsupported('unsupported');

  const AiroReleaseDistributionStatus(this.stableId);

  final String stableId;
}

enum AiroReleaseValidationCode {
  duplicateProfileId('duplicate_profile_id'),
  duplicatePackageId('duplicate_package_id'),
  missingDeviceSupportStatus('missing_device_support_status'),
  missingArtifactKind('missing_artifact_kind'),
  missingDistributionRule('missing_distribution_rule');

  const AiroReleaseValidationCode(this.stableId);

  final String stableId;
}

class AiroReleaseDistributionRule extends Equatable {
  const AiroReleaseDistributionRule({
    required this.channel,
    required this.status,
    this.track,
    this.publicArtifact = false,
    this.internalQa = false,
    this.note,
  });

  final AiroReleaseDistributionChannel channel;
  final AiroReleaseDistributionStatus status;
  final String? track;
  final bool publicArtifact;
  final bool internalQa;
  final String? note;

  bool get isPublishable =>
      status == AiroReleaseDistributionStatus.required ||
      status == AiroReleaseDistributionStatus.optional ||
      status == AiroReleaseDistributionStatus.pendingCredentials;

  Map<String, Object?> toPublicMap() {
    return {
      'channel': channel.stableId,
      'status': status.stableId,
      'track': track,
      'publicArtifact': publicArtifact,
      'internalQa': internalQa,
      'note': note,
    };
  }

  @override
  List<Object?> get props => [
    channel,
    status,
    track,
    publicArtifact,
    internalQa,
    note,
  ];
}

class AiroReleaseProfile extends Equatable {
  AiroReleaseProfile({
    required this.id,
    required this.displayName,
    required this.artifactNamePart,
    required this.releaseLine,
    required this.packageId,
    required this.entrypoint,
    required this.pubspec,
    required this.abiStrategy,
    required Iterable<AiroReleaseDeviceClass> deviceClasses,
    required Map<AiroReleaseDeviceClass, AiroReleaseSupportStatus>
    supportStatuses,
    required Iterable<AiroReleaseArtifactKind> artifactKinds,
    required Iterable<AiroReleaseDistributionRule> distributionRules,
    this.tabletStrategy = AiroReleaseTabletStrategy.notApplicable,
    this.decisionNote,
    this.schemaVersion = kAiroReleaseMatrixSchemaVersion,
  }) : deviceClasses = Set.unmodifiable(deviceClasses),
       supportStatuses = Map.unmodifiable(supportStatuses),
       artifactKinds = Set.unmodifiable(artifactKinds),
       distributionRules = List.unmodifiable(distributionRules);

  final String schemaVersion;
  final String id;
  final String displayName;
  final String artifactNamePart;
  final AiroReleaseLine releaseLine;
  final String packageId;
  final String entrypoint;
  final String pubspec;
  final AiroReleaseAbiStrategy abiStrategy;
  final Set<AiroReleaseDeviceClass> deviceClasses;
  final Map<AiroReleaseDeviceClass, AiroReleaseSupportStatus> supportStatuses;
  final Set<AiroReleaseArtifactKind> artifactKinds;
  final List<AiroReleaseDistributionRule> distributionRules;
  final AiroReleaseTabletStrategy tabletStrategy;
  final String? decisionNote;

  bool get isAndroidReleaseCandidate {
    return deviceClasses.any(
      (deviceClass) =>
          deviceClass == AiroReleaseDeviceClass.androidPhone ||
          deviceClass == AiroReleaseDeviceClass.androidTablet ||
          deviceClass == AiroReleaseDeviceClass.androidTv ||
          deviceClass == AiroReleaseDeviceClass.googleTv ||
          deviceClass == AiroReleaseDeviceClass.fireTv ||
          deviceClass == AiroReleaseDeviceClass.legacyAndroidTvBox,
    );
  }

  bool supportsArtifact(AiroReleaseArtifactKind kind) {
    return artifactKinds.contains(kind);
  }

  AiroReleaseDistributionRule? distributionFor(
    AiroReleaseDistributionChannel channel,
  ) {
    for (final rule in distributionRules) {
      if (rule.channel == channel) {
        return rule;
      }
    }
    return null;
  }

  String artifactFileName({
    required AiroReleaseArtifactKind kind,
    required String version,
    String? abi,
  }) {
    if (!supportsArtifact(kind)) {
      throw ArgumentError.value(kind, 'kind', 'Artifact is not supported.');
    }

    switch (kind) {
      case AiroReleaseArtifactKind.apk:
        final abiPart = abi == null || abi.isEmpty ? '' : '-$abi';
        return 'Airo-$artifactNamePart-$version$abiPart.apk';
      case AiroReleaseArtifactKind.playStoreAab:
        return 'Airo-$artifactNamePart-$version-Play-Store.aab';
      case AiroReleaseArtifactKind.releaseManifest:
        return 'Airo-$artifactNamePart-$version-Release-Manifest.json';
      case AiroReleaseArtifactKind.checksum:
        return 'SHA256SUMS';
      case AiroReleaseArtifactKind.releaseNotes:
        return 'Airo-$artifactNamePart-$version-Release-Notes.md';
      case AiroReleaseArtifactKind.sourceArchive:
        return 'Airo-$artifactNamePart-$version-Source.zip';
      case AiroReleaseArtifactKind.debugSymbols:
        return 'Airo-$artifactNamePart-$version-Debug-Symbols.zip';
      case AiroReleaseArtifactKind.storeMedia:
        return 'Airo-$artifactNamePart-$version-Store-Media.zip';
    }
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'displayName': displayName,
      'artifactNamePart': artifactNamePart,
      'releaseLine': releaseLine.stableId,
      'packageId': packageId,
      'entrypoint': entrypoint,
      'pubspec': pubspec,
      'abiStrategy': abiStrategy.stableId,
      'deviceClasses':
          deviceClasses.map((deviceClass) => deviceClass.stableId).toList()
            ..sort(),
      'supportStatuses': supportStatuses.map(
        (deviceClass, status) =>
            MapEntry(deviceClass.stableId, status.stableId),
      ),
      'artifactKinds': artifactKinds.map((kind) => kind.stableId).toList()
        ..sort(),
      'distributionRules': distributionRules
          .map((rule) => rule.toPublicMap())
          .toList(),
      'tabletStrategy': tabletStrategy.stableId,
      'decisionNote': decisionNote,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    id,
    displayName,
    artifactNamePart,
    releaseLine,
    packageId,
    entrypoint,
    pubspec,
    abiStrategy,
    deviceClasses,
    supportStatuses,
    artifactKinds,
    distributionRules,
    tabletStrategy,
    decisionNote,
  ];
}

class AiroReleaseValidationFinding extends Equatable {
  const AiroReleaseValidationFinding({
    required this.code,
    required this.message,
    this.profileId,
  });

  final AiroReleaseValidationCode code;
  final String message;
  final String? profileId;

  Map<String, Object?> toPublicMap() {
    return {'code': code.stableId, 'message': message, 'profileId': profileId};
  }

  @override
  List<Object?> get props => [code, message, profileId];
}

class AiroReleaseMatrix extends Equatable {
  AiroReleaseMatrix({
    required Iterable<AiroReleaseProfile> profiles,
    this.schemaVersion = kAiroReleaseMatrixSchemaVersion,
  }) : profiles = List.unmodifiable(profiles);

  factory AiroReleaseMatrix.v2Default() {
    const androidArtifactKinds = {
      AiroReleaseArtifactKind.apk,
      AiroReleaseArtifactKind.playStoreAab,
      AiroReleaseArtifactKind.releaseManifest,
      AiroReleaseArtifactKind.checksum,
      AiroReleaseArtifactKind.releaseNotes,
    };

    const mobileDistributionRules = [
      AiroReleaseDistributionRule(
        channel: AiroReleaseDistributionChannel.githubRelease,
        status: AiroReleaseDistributionStatus.required,
        publicArtifact: true,
        note: 'Public release evidence after profile qualification.',
      ),
      AiroReleaseDistributionRule(
        channel: AiroReleaseDistributionChannel.firebaseAppDistribution,
        status: AiroReleaseDistributionStatus.required,
        internalQa: true,
        note: 'Internal tester distribution before public approval.',
      ),
      AiroReleaseDistributionRule(
        channel: AiroReleaseDistributionChannel.googlePlay,
        status: AiroReleaseDistributionStatus.pendingDecision,
        note: 'First mobile/tablet Play track is not finalized.',
      ),
      AiroReleaseDistributionRule(
        channel: AiroReleaseDistributionChannel.amazonAppstore,
        status: AiroReleaseDistributionStatus.deferred,
        note: 'Not approved for the first release wave.',
      ),
      AiroReleaseDistributionRule(
        channel: AiroReleaseDistributionChannel.fDroid,
        status: AiroReleaseDistributionStatus.deferred,
        note: 'Not approved for the first release wave.',
      ),
      AiroReleaseDistributionRule(
        channel: AiroReleaseDistributionChannel.directApk,
        status: AiroReleaseDistributionStatus.pendingDecision,
        note: 'Direct APK publication remains a maintainer decision.',
      ),
    ];

    const tvDistributionRules = [
      AiroReleaseDistributionRule(
        channel: AiroReleaseDistributionChannel.githubRelease,
        status: AiroReleaseDistributionStatus.required,
        publicArtifact: true,
        note: 'Public release evidence after TV qualification.',
      ),
      AiroReleaseDistributionRule(
        channel: AiroReleaseDistributionChannel.firebaseAppDistribution,
        status: AiroReleaseDistributionStatus.optional,
        internalQa: true,
        note: 'Use where the tester device and channel support APK install.',
      ),
      AiroReleaseDistributionRule(
        channel: AiroReleaseDistributionChannel.googlePlay,
        status: AiroReleaseDistributionStatus.pendingDecision,
        note: 'First TV Play track is not finalized.',
      ),
      AiroReleaseDistributionRule(
        channel: AiroReleaseDistributionChannel.amazonAppstore,
        status: AiroReleaseDistributionStatus.deferred,
        note: 'Fire TV support is compatible/experimental until qualified.',
      ),
      AiroReleaseDistributionRule(
        channel: AiroReleaseDistributionChannel.fDroid,
        status: AiroReleaseDistributionStatus.deferred,
        note: 'Not approved for the first release wave.',
      ),
      AiroReleaseDistributionRule(
        channel: AiroReleaseDistributionChannel.directApk,
        status: AiroReleaseDistributionStatus.pendingDecision,
        note: 'Direct APK publication remains a maintainer decision.',
      ),
    ];

    return AiroReleaseMatrix(
      profiles: [
        AiroReleaseProfile(
          id: 'iptv-standalone',
          displayName: 'Airo IPTV',
          artifactNamePart: 'IPTV',
          releaseLine: AiroReleaseLine.v2,
          packageId: 'io.airo.app.iptv',
          entrypoint: 'app/lib/main_airo_iptv.dart',
          pubspec: 'app/pubspec_iptv.yaml',
          abiStrategy: AiroReleaseAbiStrategy.singleArm64Apk,
          deviceClasses: const {
            AiroReleaseDeviceClass.androidPhone,
            AiroReleaseDeviceClass.androidTablet,
          },
          supportStatuses: const {
            AiroReleaseDeviceClass.androidPhone:
                AiroReleaseSupportStatus.supported,
            AiroReleaseDeviceClass.androidTablet:
                AiroReleaseSupportStatus.adaptiveSupported,
          },
          artifactKinds: androidArtifactKinds,
          distributionRules: mobileDistributionRules,
          tabletStrategy: AiroReleaseTabletStrategy.adaptiveMobileArtifact,
          decisionNote:
              'First public mobile profile and tablet listing strategy remain '
              'maintainer decisions.',
        ),
        AiroReleaseProfile(
          id: 'mobile-streaming',
          displayName: 'Airo Streaming',
          artifactNamePart: 'Streaming',
          releaseLine: AiroReleaseLine.v2,
          packageId: 'io.airo.app.streaming',
          entrypoint: 'app/lib/main_mobile_streaming.dart',
          pubspec: 'app/pubspec_streaming.yaml',
          abiStrategy: AiroReleaseAbiStrategy.singleArm64Apk,
          deviceClasses: const {
            AiroReleaseDeviceClass.androidPhone,
            AiroReleaseDeviceClass.androidTablet,
          },
          supportStatuses: const {
            AiroReleaseDeviceClass.androidPhone:
                AiroReleaseSupportStatus.supported,
            AiroReleaseDeviceClass.androidTablet:
                AiroReleaseSupportStatus.adaptiveSupported,
          },
          artifactKinds: androidArtifactKinds,
          distributionRules: mobileDistributionRules,
          tabletStrategy: AiroReleaseTabletStrategy.adaptiveMobileArtifact,
          decisionNote:
              'First public mobile profile and tablet listing strategy remain '
              'maintainer decisions.',
        ),
        AiroReleaseProfile(
          id: 'tv',
          displayName: 'Airo TV',
          artifactNamePart: 'TV',
          releaseLine: AiroReleaseLine.v2,
          packageId: 'io.airo.app.tv',
          entrypoint: 'app/lib/main_tv.dart',
          pubspec: 'app/pubspec_tv.yaml',
          abiStrategy: AiroReleaseAbiStrategy.singleArm64Apk,
          deviceClasses: const {
            AiroReleaseDeviceClass.androidTv,
            AiroReleaseDeviceClass.googleTv,
            AiroReleaseDeviceClass.fireTv,
          },
          supportStatuses: const {
            AiroReleaseDeviceClass.androidTv:
                AiroReleaseSupportStatus.supported,
            AiroReleaseDeviceClass.googleTv: AiroReleaseSupportStatus.supported,
            AiroReleaseDeviceClass.fireTv:
                AiroReleaseSupportStatus.compatibleExperimental,
          },
          artifactKinds: androidArtifactKinds,
          distributionRules: tvDistributionRules,
          decisionNote:
              'Fire TV remains compatible/experimental until qualification '
              'evidence is attached.',
        ),
        AiroReleaseProfile(
          id: 'ios-spm',
          displayName: 'Airo iOS SPM',
          artifactNamePart: 'iOS-SPM',
          releaseLine: AiroReleaseLine.v2,
          packageId: 'com.developerscoffee.airo',
          entrypoint: 'app/lib/main.dart',
          pubspec: 'app/pubspec_ios_spm.yaml',
          abiStrategy: AiroReleaseAbiStrategy.notApplicable,
          deviceClasses: const {AiroReleaseDeviceClass.iosIpadOs},
          supportStatuses: const {
            AiroReleaseDeviceClass.iosIpadOs: AiroReleaseSupportStatus.deferred,
          },
          artifactKinds: const {},
          distributionRules: const [
            AiroReleaseDistributionRule(
              channel: AiroReleaseDistributionChannel.localValidation,
              status: AiroReleaseDistributionStatus.deferred,
              note: 'Not part of the first v2 Android publishing wave.',
            ),
          ],
          decisionNote: 'Deferred for the first v2 Android publishing wave.',
        ),
        AiroReleaseProfile(
          id: 'web-validation',
          displayName: 'Airo Web Validation',
          artifactNamePart: 'Web-Validation',
          releaseLine: AiroReleaseLine.v2,
          packageId: 'web',
          entrypoint: 'app/lib/main_airo_iptv.dart',
          pubspec: 'app/pubspec.yaml',
          abiStrategy: AiroReleaseAbiStrategy.notApplicable,
          deviceClasses: const {AiroReleaseDeviceClass.web},
          supportStatuses: const {
            AiroReleaseDeviceClass.web: AiroReleaseSupportStatus.validationOnly,
          },
          artifactKinds: const {},
          distributionRules: const [
            AiroReleaseDistributionRule(
              channel: AiroReleaseDistributionChannel.localValidation,
              status: AiroReleaseDistributionStatus.validationOnly,
              note: 'Browser validation only; not a public v2 artifact.',
            ),
          ],
          decisionNote: 'Validation only; not a public release artifact.',
        ),
      ],
    );
  }

  final String schemaVersion;
  final List<AiroReleaseProfile> profiles;

  AiroReleaseProfile profileById(String id) {
    return profiles.firstWhere(
      (profile) => profile.id == id,
      orElse: () => throw StateError('Unknown release profile: $id'),
    );
  }

  List<AiroReleaseValidationFinding> validate() {
    final findings = <AiroReleaseValidationFinding>[];
    final profileIds = <String>{};
    final packageIds = <String>{};

    for (final profile in profiles) {
      if (!profileIds.add(profile.id)) {
        findings.add(
          AiroReleaseValidationFinding(
            code: AiroReleaseValidationCode.duplicateProfileId,
            profileId: profile.id,
            message: 'Release profile IDs must be unique.',
          ),
        );
      }
      if (!packageIds.add(profile.packageId)) {
        findings.add(
          AiroReleaseValidationFinding(
            code: AiroReleaseValidationCode.duplicatePackageId,
            profileId: profile.id,
            message: 'Release profile package IDs must be unique.',
          ),
        );
      }
      for (final deviceClass in profile.deviceClasses) {
        if (!profile.supportStatuses.containsKey(deviceClass)) {
          findings.add(
            AiroReleaseValidationFinding(
              code: AiroReleaseValidationCode.missingDeviceSupportStatus,
              profileId: profile.id,
              message: 'Every device class needs an explicit support status.',
            ),
          );
        }
      }

      if (profile.isAndroidReleaseCandidate) {
        const requiredArtifactKinds = {
          AiroReleaseArtifactKind.apk,
          AiroReleaseArtifactKind.playStoreAab,
          AiroReleaseArtifactKind.releaseManifest,
          AiroReleaseArtifactKind.checksum,
        };
        for (final kind in requiredArtifactKinds) {
          if (!profile.supportsArtifact(kind)) {
            findings.add(
              AiroReleaseValidationFinding(
                code: AiroReleaseValidationCode.missingArtifactKind,
                profileId: profile.id,
                message: 'Android release candidates require ${kind.stableId}.',
              ),
            );
          }
        }
        const requiredChannels = {
          AiroReleaseDistributionChannel.githubRelease,
          AiroReleaseDistributionChannel.firebaseAppDistribution,
          AiroReleaseDistributionChannel.googlePlay,
        };
        for (final channel in requiredChannels) {
          if (profile.distributionFor(channel) == null) {
            findings.add(
              AiroReleaseValidationFinding(
                code: AiroReleaseValidationCode.missingDistributionRule,
                profileId: profile.id,
                message:
                    'Android release candidates require ${channel.stableId}.',
              ),
            );
          }
        }
      }
    }

    return findings;
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'profiles': profiles.map((profile) => profile.toPublicMap()).toList(),
    };
  }

  @override
  List<Object?> get props => [schemaVersion, profiles];
}
