import 'package:equatable/equatable.dart';

import 'release_matrix.dart';

enum AiroPlayUploadMode {
  noUpload('no_upload'),
  upload('upload');

  const AiroPlayUploadMode(this.stableId);

  final String stableId;
}

enum AiroPlayUploadTrack {
  none('none'),
  internal('internal'),
  alpha('alpha'),
  beta('beta'),
  production('production');

  const AiroPlayUploadTrack(this.stableId);

  final String stableId;

  static AiroPlayUploadTrack? fromStableId(String value) {
    for (final track in values) {
      if (track.stableId == value) {
        return track;
      }
    }
    return null;
  }
}

enum AiroPlayUploadFindingCode {
  unknownProfile('unknown_profile'),
  unsupportedTrack('unsupported_track'),
  profileNotPlayEligible('profile_not_play_eligible'),
  pendingPlayDecision('pending_play_decision'),
  missingServiceAccount('missing_service_account'),
  missingAab('missing_aab');

  const AiroPlayUploadFindingCode(this.stableId);

  final String stableId;
}

class AiroPlayUploadPlanRequest extends Equatable {
  const AiroPlayUploadPlanRequest({
    required this.profileId,
    required this.versionLabel,
    required this.buildName,
    required this.buildNumber,
    required this.requestedTrack,
    this.serviceAccountAvailable = false,
    this.expectedAabExists = true,
    this.enforceConfirmedTrack = false,
  });

  final String profileId;
  final String versionLabel;
  final String buildName;
  final String buildNumber;
  final String requestedTrack;
  final bool serviceAccountAvailable;
  final bool expectedAabExists;
  final bool enforceConfirmedTrack;

  String get artifactVersionPart => '$buildName-$buildNumber';

  @override
  List<Object?> get props => [
    profileId,
    versionLabel,
    buildName,
    buildNumber,
    requestedTrack,
    serviceAccountAvailable,
    expectedAabExists,
    enforceConfirmedTrack,
  ];
}

class AiroPlayUploadFinding extends Equatable {
  const AiroPlayUploadFinding({
    required this.code,
    required this.message,
    this.blocking = true,
  });

  final AiroPlayUploadFindingCode code;
  final String message;
  final bool blocking;

  Map<String, Object?> toPublicMap() {
    return {'code': code.stableId, 'message': message, 'blocking': blocking};
  }

  @override
  List<Object?> get props => [code, message, blocking];
}

class AiroPlayUploadPlan extends Equatable {
  AiroPlayUploadPlan({
    required this.profileId,
    required this.mode,
    required this.requestedTrack,
    required Iterable<AiroPlayUploadFinding> findings,
    this.packageId,
    this.expectedAabFileName,
    this.playConsoleUrl,
    this.schemaVersion = kAiroReleaseMatrixSchemaVersion,
  }) : findings = List.unmodifiable(findings);

  final String schemaVersion;
  final String profileId;
  final AiroPlayUploadMode mode;
  final AiroPlayUploadTrack? requestedTrack;
  final String? packageId;
  final String? expectedAabFileName;
  final String? playConsoleUrl;
  final List<AiroPlayUploadFinding> findings;

  bool get uploadRequested => mode == AiroPlayUploadMode.upload;

  bool get canUpload =>
      uploadRequested && !findings.any((finding) => finding.blocking);

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'profileId': profileId,
      'mode': mode.stableId,
      'requestedTrack': requestedTrack?.stableId,
      'packageId': packageId,
      'expectedAabFileName': expectedAabFileName,
      'playConsoleUrl': playConsoleUrl,
      'canUpload': canUpload,
      'findings': findings.map((finding) => finding.toPublicMap()).toList(),
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    profileId,
    mode,
    requestedTrack,
    packageId,
    expectedAabFileName,
    playConsoleUrl,
    findings,
  ];
}

class AiroPlayUploadPlanner {
  const AiroPlayUploadPlanner({required this.matrix});

  final AiroReleaseMatrix matrix;

  AiroPlayUploadPlan plan(AiroPlayUploadPlanRequest request) {
    final findings = <AiroPlayUploadFinding>[];
    final track = AiroPlayUploadTrack.fromStableId(request.requestedTrack);

    if (track == null) {
      findings.add(
        AiroPlayUploadFinding(
          code: AiroPlayUploadFindingCode.unsupportedTrack,
          message: 'Unsupported Play track: ${request.requestedTrack}.',
        ),
      );
    }

    AiroReleaseProfile? profile;
    try {
      profile = matrix.profileById(request.profileId);
    } on StateError {
      findings.add(
        AiroPlayUploadFinding(
          code: AiroPlayUploadFindingCode.unknownProfile,
          message: 'Unknown release profile: ${request.profileId}.',
        ),
      );
    }

    final mode = track == AiroPlayUploadTrack.none
        ? AiroPlayUploadMode.noUpload
        : AiroPlayUploadMode.upload;

    if (profile == null) {
      return AiroPlayUploadPlan(
        profileId: request.profileId,
        mode: mode,
        requestedTrack: track,
        findings: findings,
      );
    }

    final googlePlayRule = profile.distributionFor(
      AiroReleaseDistributionChannel.googlePlay,
    );
    final expectedAabFileName =
        profile.supportsArtifact(AiroReleaseArtifactKind.playStoreAab)
        ? profile.artifactFileName(
            kind: AiroReleaseArtifactKind.playStoreAab,
            version: request.artifactVersionPart,
          )
        : null;
    final playConsoleUrl = track == null || track == AiroPlayUploadTrack.none
        ? null
        : 'https://play.google.com/console/u/0/developers/app/'
              '${profile.packageId}/tracks/${track.stableId}';

    if (mode == AiroPlayUploadMode.noUpload) {
      return AiroPlayUploadPlan(
        profileId: request.profileId,
        mode: mode,
        requestedTrack: track,
        packageId: profile.packageId,
        expectedAabFileName: expectedAabFileName,
        playConsoleUrl: playConsoleUrl,
        findings: findings,
      );
    }

    if (googlePlayRule == null ||
        !profile.supportsArtifact(AiroReleaseArtifactKind.playStoreAab) ||
        googlePlayRule.status == AiroReleaseDistributionStatus.deferred ||
        googlePlayRule.status == AiroReleaseDistributionStatus.unsupported ||
        googlePlayRule.status == AiroReleaseDistributionStatus.validationOnly) {
      findings.add(
        AiroPlayUploadFinding(
          code: AiroPlayUploadFindingCode.profileNotPlayEligible,
          message: 'Profile ${profile.id} is not eligible for Play upload.',
        ),
      );
    }

    if (googlePlayRule?.status ==
        AiroReleaseDistributionStatus.pendingDecision) {
      findings.add(
        AiroPlayUploadFinding(
          code: AiroPlayUploadFindingCode.pendingPlayDecision,
          blocking: request.enforceConfirmedTrack,
          message:
              'First Play track for ${profile.id} is still pending maintainer '
              'confirmation.',
        ),
      );
    }

    if (!request.serviceAccountAvailable) {
      findings.add(
        const AiroPlayUploadFinding(
          code: AiroPlayUploadFindingCode.missingServiceAccount,
          message:
              'Google Play service account credentials are required for upload.',
        ),
      );
    }

    if (!request.expectedAabExists) {
      findings.add(
        AiroPlayUploadFinding(
          code: AiroPlayUploadFindingCode.missingAab,
          message: 'Expected Play AAB was not found: $expectedAabFileName.',
        ),
      );
    }

    return AiroPlayUploadPlan(
      profileId: request.profileId,
      mode: mode,
      requestedTrack: track,
      packageId: profile.packageId,
      expectedAabFileName: expectedAabFileName,
      playConsoleUrl: playConsoleUrl,
      findings: findings,
    );
  }
}
