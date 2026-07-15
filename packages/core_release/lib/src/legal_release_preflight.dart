import 'package:equatable/equatable.dart';

import 'release_matrix.dart';

enum AiroPrivateDependencyConfirmation {
  unknown('unknown'),
  confirmedAbsent('confirmed_absent'),
  confirmedPresentApproved('confirmed_present_approved');

  const AiroPrivateDependencyConfirmation(this.stableId);

  final String stableId;

  static AiroPrivateDependencyConfirmation parse(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('-', '_');
    for (final confirmation in values) {
      if (confirmation.stableId == normalized) {
        return confirmation;
      }
    }
    throw ArgumentError.value(
      value,
      'value',
      'Expected unknown, confirmed_absent, or confirmed_present_approved.',
    );
  }
}

enum AiroReleaseProvenanceDecision {
  unknown('unknown'),
  sha256OnlyAccepted('sha256_only_accepted'),
  signedOrSlsaRequired('signed_or_slsa_required');

  const AiroReleaseProvenanceDecision(this.stableId);

  final String stableId;

  static AiroReleaseProvenanceDecision parse(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('-', '_');
    for (final decision in values) {
      if (decision.stableId == normalized) {
        return decision;
      }
    }
    throw ArgumentError.value(
      value,
      'value',
      'Expected unknown, sha256_only_accepted, or signed_or_slsa_required.',
    );
  }
}

enum AiroLegalReleaseFindingCode {
  unknownProfile('unknown_profile'),
  missingRootLicense('missing_root_license'),
  rootLicenseNotMit('root_license_not_mit'),
  missingLicenseReview('missing_license_review'),
  missingThirdPartyNotices('missing_third_party_notices'),
  missingPackageLicense('missing_package_license'),
  packageLicenseMismatch('package_license_mismatch'),
  privateDependencyConfirmationMissing(
    'private_dependency_confirmation_missing',
  ),
  provenanceDecisionMissing('provenance_decision_missing');

  const AiroLegalReleaseFindingCode(this.stableId);

  final String stableId;
}

class AiroPackageLicenseStatus extends Equatable {
  const AiroPackageLicenseStatus({
    required this.packageName,
    required this.path,
    required this.licensePresent,
    required this.matchesRootLicense,
    this.thirdPartyNoticeCovered = false,
  });

  final String packageName;
  final String path;
  final bool licensePresent;
  final bool matchesRootLicense;
  final bool thirdPartyNoticeCovered;

  Map<String, Object?> toPublicMap() {
    return {
      'packageName': packageName,
      'path': path,
      'licensePresent': licensePresent,
      'matchesRootLicense': matchesRootLicense,
      if (thirdPartyNoticeCovered)
        'thirdPartyNoticeCovered': thirdPartyNoticeCovered,
    };
  }

  @override
  List<Object?> get props => [
    packageName,
    path,
    licensePresent,
    matchesRootLicense,
    thirdPartyNoticeCovered,
  ];
}

class AiroLegalReleaseFinding extends Equatable {
  const AiroLegalReleaseFinding({
    required this.code,
    required this.message,
    this.profileId,
    this.packageName,
    this.blocking = true,
  });

  final AiroLegalReleaseFindingCode code;
  final String message;
  final String? profileId;
  final String? packageName;
  final bool blocking;

  Map<String, Object?> toPublicMap() {
    return {
      'code': code.stableId,
      if (profileId != null) 'profileId': profileId,
      if (packageName != null) 'packageName': packageName,
      'message': message,
      'blocking': blocking,
    };
  }

  @override
  List<Object?> get props => [code, message, profileId, packageName, blocking];
}

class AiroLegalReleasePreflightRequest extends Equatable {
  AiroLegalReleasePreflightRequest({
    required Iterable<String> profileIds,
    required Iterable<AiroPackageLicenseStatus> packageLicenses,
    required this.rootLicensePresent,
    required this.rootLicenseText,
    required this.licenseReviewPresent,
    required this.thirdPartyNoticesPresent,
    this.privateDependencyConfirmation =
        AiroPrivateDependencyConfirmation.unknown,
    this.provenanceDecision = AiroReleaseProvenanceDecision.unknown,
  }) : profileIds = List.unmodifiable(profileIds),
       packageLicenses = List.unmodifiable(packageLicenses);

  final List<String> profileIds;
  final bool rootLicensePresent;
  final String rootLicenseText;
  final bool licenseReviewPresent;
  final bool thirdPartyNoticesPresent;
  final List<AiroPackageLicenseStatus> packageLicenses;
  final AiroPrivateDependencyConfirmation privateDependencyConfirmation;
  final AiroReleaseProvenanceDecision provenanceDecision;

  @override
  List<Object?> get props => [
    profileIds,
    rootLicensePresent,
    rootLicenseText,
    licenseReviewPresent,
    thirdPartyNoticesPresent,
    packageLicenses,
    privateDependencyConfirmation,
    provenanceDecision,
  ];
}

class AiroLegalReleasePreflight extends Equatable {
  AiroLegalReleasePreflight({
    required Iterable<String> profileIds,
    required Iterable<AiroPackageLicenseStatus> packageLicenses,
    required this.rootLicensePresent,
    required this.rootLicenseKind,
    required this.licenseReviewPresent,
    required this.thirdPartyNoticesPresent,
    required this.privateDependencyConfirmation,
    required this.provenanceDecision,
    required Iterable<AiroLegalReleaseFinding> findings,
    this.schemaVersion = kAiroReleaseMatrixSchemaVersion,
  }) : profileIds = List.unmodifiable(profileIds),
       packageLicenses = List.unmodifiable(packageLicenses),
       findings = List.unmodifiable(findings);

  final String schemaVersion;
  final List<String> profileIds;
  final bool rootLicensePresent;
  final String rootLicenseKind;
  final bool licenseReviewPresent;
  final bool thirdPartyNoticesPresent;
  final List<AiroPackageLicenseStatus> packageLicenses;
  final AiroPrivateDependencyConfirmation privateDependencyConfirmation;
  final AiroReleaseProvenanceDecision provenanceDecision;
  final List<AiroLegalReleaseFinding> findings;

  bool get ready => !findings.any((finding) => finding.blocking);

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'ready': ready,
      'profileIds': profileIds,
      'rootLicensePresent': rootLicensePresent,
      'rootLicenseKind': rootLicenseKind,
      'licenseReviewPresent': licenseReviewPresent,
      'thirdPartyNoticesPresent': thirdPartyNoticesPresent,
      'privateDependencyConfirmation': privateDependencyConfirmation.stableId,
      'provenanceDecision': provenanceDecision.stableId,
      'packageLicenses': packageLicenses
          .map((license) => license.toPublicMap())
          .toList(),
      'findings': findings.map((finding) => finding.toPublicMap()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Legal Release Preflight')
      ..writeln()
      ..writeln('| Area | Status |')
      ..writeln('| --- | --- |')
      ..writeln('| Ready | `$ready` |')
      ..writeln('| Profiles | `${profileIds.join(', ')}` |')
      ..writeln('| Root license | `$rootLicenseKind` |')
      ..writeln('| License review doc | `$licenseReviewPresent` |')
      ..writeln('| Third-party notices | `$thirdPartyNoticesPresent` |')
      ..writeln(
        '| Private dependency confirmation | '
        '`${privateDependencyConfirmation.stableId}` |',
      )
      ..writeln('| Provenance decision | `${provenanceDecision.stableId}` |')
      ..writeln()
      ..writeln('## Package Licenses')
      ..writeln()
      ..writeln('| Package | License | Matches root | Path |')
      ..writeln('| --- | --- | --- | --- |');

    for (final packageLicense in packageLicenses) {
      buffer.writeln(
        '| `${packageLicense.packageName}` | '
        '`${packageLicense.licensePresent}` | '
        '`${packageLicense.matchesRootLicense}` | '
        '`${packageLicense.path}` |',
      );
    }

    if (findings.isEmpty) {
      buffer
        ..writeln()
        ..writeln('No findings.');
      return buffer.toString();
    }

    buffer
      ..writeln()
      ..writeln('## Findings')
      ..writeln()
      ..writeln('| Code | Profile | Package | Blocking | Message |')
      ..writeln('| --- | --- | --- | --- | --- |');
    for (final finding in findings) {
      buffer.writeln(
        '| `${finding.code.stableId}` | `${finding.profileId ?? ''}` | '
        '`${finding.packageName ?? ''}` | `${finding.blocking}` | '
        '${finding.message} |',
      );
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    profileIds,
    rootLicensePresent,
    rootLicenseKind,
    licenseReviewPresent,
    thirdPartyNoticesPresent,
    packageLicenses,
    privateDependencyConfirmation,
    provenanceDecision,
    findings,
  ];
}

class AiroLegalReleasePreflightRunner {
  const AiroLegalReleasePreflightRunner({required this.matrix});

  final AiroReleaseMatrix matrix;

  AiroLegalReleasePreflight run(AiroLegalReleasePreflightRequest request) {
    final findings = <AiroLegalReleaseFinding>[];
    final profileIds = <String>[];

    for (final profileId in request.profileIds) {
      try {
        matrix.profileById(profileId);
        profileIds.add(profileId);
      } on StateError {
        findings.add(
          AiroLegalReleaseFinding(
            code: AiroLegalReleaseFindingCode.unknownProfile,
            profileId: profileId,
            message: 'Unknown release profile: $profileId.',
          ),
        );
      }
    }

    final rootLicenseKind = _licenseKind(request.rootLicenseText);
    if (!request.rootLicensePresent) {
      findings.add(
        const AiroLegalReleaseFinding(
          code: AiroLegalReleaseFindingCode.missingRootLicense,
          message: 'Add a root LICENSE before public distribution.',
        ),
      );
    } else if (rootLicenseKind != 'MIT') {
      findings.add(
        AiroLegalReleaseFinding(
          code: AiroLegalReleaseFindingCode.rootLicenseNotMit,
          message:
              'Root LICENSE is `$rootLicenseKind`; update the release legal '
              'review if the project license changes from MIT.',
        ),
      );
    }

    if (!request.licenseReviewPresent) {
      findings.add(
        const AiroLegalReleaseFinding(
          code: AiroLegalReleaseFindingCode.missingLicenseReview,
          message:
              'Add docs/release/V2_LICENSE_REVIEW.md before public '
              'distribution.',
        ),
      );
    }
    if (!request.thirdPartyNoticesPresent) {
      findings.add(
        const AiroLegalReleaseFinding(
          code: AiroLegalReleaseFindingCode.missingThirdPartyNotices,
          message:
              'Add docs/release/V2_THIRD_PARTY_NOTICES.md before public '
              'distribution.',
        ),
      );
    }

    for (final packageLicense in request.packageLicenses) {
      if (!packageLicense.licensePresent) {
        findings.add(
          AiroLegalReleaseFinding(
            code: AiroLegalReleaseFindingCode.missingPackageLicense,
            packageName: packageLicense.packageName,
            message: packageLicense.thirdPartyNoticeCovered
                ? 'Add or restore the third-party LICENSE for vendored '
                      'package ${packageLicense.packageName}.'
                : 'Add a LICENSE file for Airo-owned package '
                      '${packageLicense.packageName}.',
          ),
        );
      } else if (!packageLicense.thirdPartyNoticeCovered &&
          !packageLicense.matchesRootLicense) {
        findings.add(
          AiroLegalReleaseFinding(
            code: AiroLegalReleaseFindingCode.packageLicenseMismatch,
            packageName: packageLicense.packageName,
            message:
                'Package ${packageLicense.packageName} has a LICENSE that '
                'does not match the root project license.',
          ),
        );
      }
    }

    if (request.privateDependencyConfirmation ==
        AiroPrivateDependencyConfirmation.unknown) {
      findings.add(
        const AiroLegalReleaseFinding(
          code:
              AiroLegalReleaseFindingCode.privateDependencyConfirmationMissing,
          message:
              'Maintainer must confirm whether private, commercial, gated, or '
              'restricted-license dependencies are bundled in release artifacts.',
        ),
      );
    }

    if (request.provenanceDecision == AiroReleaseProvenanceDecision.unknown) {
      findings.add(
        const AiroLegalReleaseFinding(
          code: AiroLegalReleaseFindingCode.provenanceDecisionMissing,
          message:
              'Maintainer must decide whether SHA256-only artifacts are enough '
              'or signed/SLSA provenance is required before public release.',
        ),
      );
    }

    return AiroLegalReleasePreflight(
      profileIds: profileIds,
      rootLicensePresent: request.rootLicensePresent,
      rootLicenseKind: rootLicenseKind,
      licenseReviewPresent: request.licenseReviewPresent,
      thirdPartyNoticesPresent: request.thirdPartyNoticesPresent,
      packageLicenses: request.packageLicenses,
      privateDependencyConfirmation: request.privateDependencyConfirmation,
      provenanceDecision: request.provenanceDecision,
      findings: findings,
    );
  }

  String _licenseKind(String text) {
    final normalized = text.toLowerCase();
    if (normalized.contains('mit license') &&
        normalized.contains('permission is hereby granted')) {
      return 'MIT';
    }
    if (text.trim().isEmpty) {
      return 'missing';
    }
    return 'unknown';
  }
}
