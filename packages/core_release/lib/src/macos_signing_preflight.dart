import 'package:equatable/equatable.dart';

import 'release_matrix.dart';

enum AiroMacosSigningInput {
  appleCertificateBase64('APPLE_CERTIFICATE_BASE64'),
  appleCertificatePassword('APPLE_CERTIFICATE_PASSWORD'),
  appleKeychainPassword('APPLE_KEYCHAIN_PASSWORD'),
  macosCodesignIdentity('MACOS_CODESIGN_IDENTITY'),
  appleId('APPLE_ID'),
  appleTeamId('APPLE_TEAM_ID'),
  appleAppSpecificPassword('APPLE_APP_SPECIFIC_PASSWORD');

  const AiroMacosSigningInput(this.environmentName);

  final String environmentName;
}

enum AiroMacosSigningFindingCode {
  unknownProfile('unknown_profile'),
  profileNotMacosEligible('profile_not_macos_eligible'),
  missingMacosBundleId('missing_macos_bundle_id'),
  signingDisabled('signing_disabled'),
  notarizationDisabled('notarization_disabled'),
  missingSigningInput('missing_signing_input'),
  missingNotarizationInput('missing_notarization_input'),
  invalidCertificateBase64('invalid_certificate_base64');

  const AiroMacosSigningFindingCode(this.stableId);

  final String stableId;
}

class AiroMacosSigningInputStatus extends Equatable {
  const AiroMacosSigningInputStatus({
    required this.input,
    required this.present,
    this.source,
  });

  final AiroMacosSigningInput input;
  final bool present;
  final String? source;

  Map<String, Object?> toPublicMap() {
    return {
      'name': input.environmentName,
      'present': present,
      if (source != null) 'source': source,
    };
  }

  @override
  List<Object?> get props => [input, present, source];
}

class AiroMacosSigningFinding extends Equatable {
  const AiroMacosSigningFinding({
    required this.code,
    required this.message,
    this.input,
    this.blocking = true,
  });

  final AiroMacosSigningFindingCode code;
  final String message;
  final AiroMacosSigningInput? input;
  final bool blocking;

  Map<String, Object?> toPublicMap() {
    return {
      'code': code.stableId,
      if (input != null) 'input': input!.environmentName,
      'message': message,
      'blocking': blocking,
    };
  }

  @override
  List<Object?> get props => [code, message, input, blocking];
}

class AiroMacosSigningPreflightRequest extends Equatable {
  const AiroMacosSigningPreflightRequest({
    required this.profileId,
    this.environment = const {},
    this.requireSigning = true,
    this.requireNotarization = true,
    this.certificateFileExists = false,
  });

  final String profileId;
  final Map<String, String> environment;
  final bool requireSigning;
  final bool requireNotarization;
  final bool certificateFileExists;

  @override
  List<Object?> get props => [
    profileId,
    environment,
    requireSigning,
    requireNotarization,
    certificateFileExists,
  ];
}

class AiroMacosSigningPreflight extends Equatable {
  AiroMacosSigningPreflight({
    required this.profileId,
    required this.profileDisplayName,
    required this.bundleId,
    required this.requireSigning,
    required this.requireNotarization,
    required Iterable<AiroMacosSigningInputStatus> inputs,
    required Iterable<AiroMacosSigningFinding> findings,
    this.schemaVersion = kAiroReleaseMatrixSchemaVersion,
  }) : inputs = List.unmodifiable(inputs),
       findings = List.unmodifiable(findings);

  final String schemaVersion;
  final String profileId;
  final String? profileDisplayName;
  final String? bundleId;
  final bool requireSigning;
  final bool requireNotarization;
  final List<AiroMacosSigningInputStatus> inputs;
  final List<AiroMacosSigningFinding> findings;

  bool get signingReady {
    return !findings.any(
      (finding) =>
          finding.blocking &&
          (finding.code == AiroMacosSigningFindingCode.missingSigningInput ||
              finding.code ==
                  AiroMacosSigningFindingCode.invalidCertificateBase64 ||
              finding.code == AiroMacosSigningFindingCode.unknownProfile ||
              finding.code ==
                  AiroMacosSigningFindingCode.profileNotMacosEligible ||
              finding.code == AiroMacosSigningFindingCode.missingMacosBundleId),
    );
  }

  bool get notarizationReady {
    return !findings.any(
      (finding) =>
          finding.blocking &&
          (finding.code ==
                  AiroMacosSigningFindingCode.missingNotarizationInput ||
              finding.code == AiroMacosSigningFindingCode.unknownProfile ||
              finding.code ==
                  AiroMacosSigningFindingCode.profileNotMacosEligible ||
              finding.code == AiroMacosSigningFindingCode.missingMacosBundleId),
    );
  }

  bool get ready => !findings.any((finding) => finding.blocking);

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'ready': ready,
      'profileId': profileId,
      'profileDisplayName': profileDisplayName,
      'bundleId': bundleId,
      'requireSigning': requireSigning,
      'requireNotarization': requireNotarization,
      'signingReady': signingReady,
      'notarizationReady': notarizationReady,
      'inputs': inputs.map((input) => input.toPublicMap()).toList(),
      'findings': findings.map((finding) => finding.toPublicMap()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# macOS Signing And Notarization Preflight')
      ..writeln()
      ..writeln('| Area | Status |')
      ..writeln('| --- | --- |')
      ..writeln('| Ready | `$ready` |')
      ..writeln('| Profile | `$profileId` |')
      ..writeln('| Bundle ID | `${bundleId ?? ''}` |')
      ..writeln('| Require signing | `$requireSigning` |')
      ..writeln('| Require notarization | `$requireNotarization` |')
      ..writeln('| Signing | ${signingReady ? 'ready' : 'blocked'} |')
      ..writeln('| Notarization | ${notarizationReady ? 'ready' : 'blocked'} |')
      ..writeln()
      ..writeln('## Inputs')
      ..writeln()
      ..writeln('| Input | Present | Source |')
      ..writeln('| --- | --- | --- |');

    for (final input in inputs) {
      buffer.writeln(
        '| `${input.input.environmentName}` | `${input.present}` | '
        '${input.source ?? ''} |',
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
      ..writeln('| Code | Input | Blocking | Message |')
      ..writeln('| --- | --- | --- | --- |');
    for (final finding in findings) {
      buffer.writeln(
        '| `${finding.code.stableId}` | '
        '`${finding.input?.environmentName ?? ''}` | '
        '`${finding.blocking}` | ${finding.message} |',
      );
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    profileId,
    profileDisplayName,
    bundleId,
    requireSigning,
    requireNotarization,
    inputs,
    findings,
  ];
}

class AiroMacosSigningPreflightRunner {
  const AiroMacosSigningPreflightRunner({required this.matrix});

  static const List<AiroMacosSigningInput> signingInputs = [
    AiroMacosSigningInput.appleCertificateBase64,
    AiroMacosSigningInput.appleCertificatePassword,
    AiroMacosSigningInput.appleKeychainPassword,
    AiroMacosSigningInput.macosCodesignIdentity,
  ];

  static const List<AiroMacosSigningInput> notarizationInputs = [
    AiroMacosSigningInput.appleId,
    AiroMacosSigningInput.appleTeamId,
    AiroMacosSigningInput.appleAppSpecificPassword,
  ];

  final AiroReleaseMatrix matrix;

  AiroMacosSigningPreflight run(AiroMacosSigningPreflightRequest request) {
    final findings = <AiroMacosSigningFinding>[];
    final inputs = <AiroMacosSigningInputStatus>[];
    final effectiveRequireSigning =
        request.requireSigning || request.requireNotarization;

    AiroReleaseProfile? profile;
    try {
      profile = matrix.profileById(request.profileId);
    } on StateError {
      findings.add(
        AiroMacosSigningFinding(
          code: AiroMacosSigningFindingCode.unknownProfile,
          message: 'Unknown release profile: ${request.profileId}.',
        ),
      );
    }

    final macosEligible =
        profile != null &&
        profile.supportsArtifact(AiroReleaseArtifactKind.macosZip) &&
        profile.supportsArtifact(AiroReleaseArtifactKind.macosDmg) &&
        profile.distributionFor(
              AiroReleaseDistributionChannel.directMacosDownload,
            ) !=
            null;
    final bundleId = profile?.platformPackageIds['macos'];

    if (profile != null && !macosEligible) {
      findings.add(
        AiroMacosSigningFinding(
          code: AiroMacosSigningFindingCode.profileNotMacosEligible,
          message:
              'Release profile ${request.profileId} does not produce macOS '
              'zip and DMG artifacts for public distribution.',
        ),
      );
    }
    if (macosEligible && (bundleId == null || bundleId.trim().isEmpty)) {
      findings.add(
        AiroMacosSigningFinding(
          code: AiroMacosSigningFindingCode.missingMacosBundleId,
          message:
              'Release profile ${request.profileId} is missing a macOS bundle '
              'identifier in the release matrix.',
        ),
      );
    }

    if (!effectiveRequireSigning) {
      findings.add(
        const AiroMacosSigningFinding(
          code: AiroMacosSigningFindingCode.signingDisabled,
          blocking: false,
          message:
              'Developer ID signing is disabled; generated macOS artifacts '
              'must remain internal validation artifacts.',
        ),
      );
    }
    if (!request.requireNotarization) {
      findings.add(
        const AiroMacosSigningFinding(
          code: AiroMacosSigningFindingCode.notarizationDisabled,
          blocking: false,
          message:
              'Notarization is disabled; generated macOS artifacts must not '
              'be published as public consumer-ready downloads.',
        ),
      );
    }

    for (final input in signingInputs) {
      final source = _sourceFor(request, input);
      final present = source != null;
      inputs.add(
        AiroMacosSigningInputStatus(
          input: input,
          present: present,
          source: source,
        ),
      );
      if (effectiveRequireSigning && !present) {
        findings.add(
          AiroMacosSigningFinding(
            input: input,
            code: AiroMacosSigningFindingCode.missingSigningInput,
            message:
                'Set ${input.environmentName} before running macOS release '
                'workflows that require Developer ID signing.',
          ),
        );
      }
    }

    for (final input in notarizationInputs) {
      final source = _sourceFor(request, input);
      final present = source != null;
      inputs.add(
        AiroMacosSigningInputStatus(
          input: input,
          present: present,
          source: source,
        ),
      );
      if (request.requireNotarization && !present) {
        findings.add(
          AiroMacosSigningFinding(
            input: input,
            code: AiroMacosSigningFindingCode.missingNotarizationInput,
            message:
                'Set ${input.environmentName} before running macOS release '
                'workflows with require_notarization=true.',
          ),
        );
      }
    }

    final certificateValue = request
        .environment[AiroMacosSigningInput
            .appleCertificateBase64
            .environmentName]
        ?.trim();
    if (effectiveRequireSigning &&
        certificateValue != null &&
        certificateValue.isNotEmpty &&
        !_looksBase64(certificateValue)) {
      findings.add(
        const AiroMacosSigningFinding(
          input: AiroMacosSigningInput.appleCertificateBase64,
          code: AiroMacosSigningFindingCode.invalidCertificateBase64,
          message:
              'APPLE_CERTIFICATE_BASE64 is present but is not shaped like a '
              'base64-encoded Developer ID certificate export.',
        ),
      );
    }

    return AiroMacosSigningPreflight(
      profileId: request.profileId,
      profileDisplayName: profile?.displayName,
      bundleId: bundleId,
      requireSigning: effectiveRequireSigning,
      requireNotarization: request.requireNotarization,
      inputs: inputs,
      findings: findings,
    );
  }

  String? _sourceFor(
    AiroMacosSigningPreflightRequest request,
    AiroMacosSigningInput input,
  ) {
    final envValue = request.environment[input.environmentName]?.trim();
    if (envValue != null && envValue.isNotEmpty) {
      return 'env:${input.environmentName}';
    }
    if (input == AiroMacosSigningInput.appleCertificateBase64 &&
        request.certificateFileExists) {
      return 'file:certificates/developer-id-application.p12';
    }
    return null;
  }

  bool _looksBase64(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), '');
    if (normalized.length < 16 || normalized.length % 4 != 0) {
      return false;
    }
    return RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(normalized);
  }
}
