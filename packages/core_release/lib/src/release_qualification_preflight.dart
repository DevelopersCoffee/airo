import 'package:equatable/equatable.dart';

import 'release_matrix.dart';

enum AiroReleaseQualificationMode {
  internal('internal'),
  public('public');

  const AiroReleaseQualificationMode(this.stableId);

  final String stableId;

  static AiroReleaseQualificationMode parse(String value) {
    final normalized = value.trim().toLowerCase();
    for (final mode in values) {
      if (mode.stableId == normalized) {
        return mode;
      }
    }
    throw ArgumentError.value(value, 'value', 'Expected internal or public.');
  }
}

enum AiroReleaseQualificationEvidenceType {
  physicalDevice('physical-device'),
  wideLayout('wide-layout');

  const AiroReleaseQualificationEvidenceType(this.stableId);

  final String stableId;
}

enum AiroReleaseQualificationResult {
  passed('passed'),
  failed('failed'),
  missing('missing'),
  waived('waived');

  const AiroReleaseQualificationResult(this.stableId);

  final String stableId;
}

enum AiroReleaseQualificationFindingCode {
  unknownProfile('unknown_profile'),
  missingArtifactFilename('missing_artifact_filename'),
  missingArtifactChecksum('missing_artifact_checksum'),
  missingRequiredEvidence('missing_required_evidence'),
  incompleteEvidenceDevice('incomplete_evidence_device'),
  failedEvidence('failed_evidence'),
  incompleteWaiver('incomplete_waiver');

  const AiroReleaseQualificationFindingCode(this.stableId);

  final String stableId;
}

class AiroReleaseArtifactEvidence extends Equatable {
  const AiroReleaseArtifactEvidence({
    required this.profileId,
    required this.packageId,
    required this.filename,
    required this.artifactType,
    required this.sha256,
  });

  final String profileId;
  final String packageId;
  final String filename;
  final String artifactType;
  final String sha256;

  bool get isApk {
    return _normalize(artifactType) == 'apk' ||
        filename.toLowerCase().endsWith('.apk');
  }

  Map<String, Object?> toPublicMap() {
    return {
      'profileId': profileId,
      'packageId': packageId,
      'filename': filename,
      'artifactType': artifactType,
      'sha256': sha256,
    };
  }

  @override
  List<Object?> get props => [
    profileId,
    packageId,
    filename,
    artifactType,
    sha256,
  ];
}

class AiroReleaseQualificationRequirement extends Equatable {
  const AiroReleaseQualificationRequirement({
    required this.profileId,
    required this.deviceClass,
    required this.evidenceType,
  });

  final String profileId;
  final AiroReleaseDeviceClass deviceClass;
  final AiroReleaseQualificationEvidenceType evidenceType;

  Map<String, Object?> toPublicMap() {
    return {
      'profileId': profileId,
      'deviceClass': deviceClass.stableId,
      'evidenceType': evidenceType.stableId,
    };
  }

  @override
  List<Object?> get props => [profileId, deviceClass, evidenceType];
}

class AiroReleaseQualificationCheck extends Equatable {
  const AiroReleaseQualificationCheck({
    required this.profileId,
    required this.filename,
    required this.deviceClass,
    required this.evidenceType,
    required this.deviceModel,
    required this.osVersion,
    required this.result,
    this.notes = '',
  });

  final String profileId;
  final String filename;
  final AiroReleaseDeviceClass deviceClass;
  final AiroReleaseQualificationEvidenceType evidenceType;
  final String deviceModel;
  final String osVersion;
  final AiroReleaseQualificationResult result;
  final String notes;

  Map<String, Object?> toPublicMap() {
    return {
      'profileId': profileId,
      'filename': filename,
      'deviceClass': deviceClass.stableId,
      'evidenceType': evidenceType.stableId,
      'deviceModel': deviceModel,
      'osVersion': osVersion,
      'result': result.stableId,
      'notes': notes,
    };
  }

  @override
  List<Object?> get props => [
    profileId,
    filename,
    deviceClass,
    evidenceType,
    deviceModel,
    osVersion,
    result,
    notes,
  ];
}

class AiroReleaseQualificationWaiver extends Equatable {
  const AiroReleaseQualificationWaiver({
    required this.profileId,
    required this.deviceClass,
    required this.reason,
    required this.approvedBy,
    this.filename = '',
  });

  final String profileId;
  final String filename;
  final AiroReleaseDeviceClass deviceClass;
  final String reason;
  final String approvedBy;

  bool get complete => reason.trim().isNotEmpty && approvedBy.trim().isNotEmpty;

  Map<String, Object?> toPublicMap() {
    return {
      'profileId': profileId,
      if (filename.isNotEmpty) 'filename': filename,
      'deviceClass': deviceClass.stableId,
      'reason': reason,
      'approvedBy': approvedBy,
    };
  }

  @override
  List<Object?> get props => [
    profileId,
    filename,
    deviceClass,
    reason,
    approvedBy,
  ];
}

class AiroReleaseQualificationFinding extends Equatable {
  const AiroReleaseQualificationFinding({
    required this.code,
    required this.message,
    this.profileId,
    this.filename,
    this.deviceClass,
    this.blocking = true,
  });

  final AiroReleaseQualificationFindingCode code;
  final String message;
  final String? profileId;
  final String? filename;
  final AiroReleaseDeviceClass? deviceClass;
  final bool blocking;

  Map<String, Object?> toPublicMap() {
    return {
      'code': code.stableId,
      if (profileId != null) 'profileId': profileId,
      if (filename != null) 'filename': filename,
      if (deviceClass != null) 'deviceClass': deviceClass!.stableId,
      'message': message,
      'blocking': blocking,
    };
  }

  @override
  List<Object?> get props => [
    code,
    message,
    profileId,
    filename,
    deviceClass,
    blocking,
  ];
}

class AiroReleaseQualificationRow extends Equatable {
  const AiroReleaseQualificationRow({
    required this.profileId,
    required this.packageId,
    required this.filename,
    required this.sha256,
    required this.deviceClass,
    required this.evidenceType,
    required this.result,
    this.deviceModel = '',
    this.osVersion = '',
    this.notes = '',
  });

  final String profileId;
  final String packageId;
  final String filename;
  final String sha256;
  final AiroReleaseDeviceClass deviceClass;
  final AiroReleaseQualificationEvidenceType evidenceType;
  final AiroReleaseQualificationResult result;
  final String deviceModel;
  final String osVersion;
  final String notes;

  Map<String, Object?> toPublicMap() {
    return {
      'profileId': profileId,
      'packageId': packageId,
      'filename': filename,
      'sha256': sha256,
      'deviceClass': deviceClass.stableId,
      'evidenceType': evidenceType.stableId,
      'result': result.stableId,
      'deviceModel': deviceModel,
      'osVersion': osVersion,
      'notes': notes,
    };
  }

  @override
  List<Object?> get props => [
    profileId,
    packageId,
    filename,
    sha256,
    deviceClass,
    evidenceType,
    result,
    deviceModel,
    osVersion,
    notes,
  ];
}

class AiroReleaseQualificationPreflight extends Equatable {
  AiroReleaseQualificationPreflight({
    required this.mode,
    required Iterable<AiroReleaseQualificationRow> rows,
    required Iterable<AiroReleaseQualificationFinding> findings,
    this.schemaVersion = kAiroReleaseMatrixSchemaVersion,
  }) : rows = List.unmodifiable(rows),
       findings = List.unmodifiable(findings);

  final String schemaVersion;
  final AiroReleaseQualificationMode mode;
  final List<AiroReleaseQualificationRow> rows;
  final List<AiroReleaseQualificationFinding> findings;

  bool get publicReady => !findings.any((finding) => finding.blocking);
  bool get dispatchReady =>
      mode == AiroReleaseQualificationMode.internal || publicReady;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'mode': mode.stableId,
      'publicReady': publicReady,
      'dispatchReady': dispatchReady,
      'rows': rows.map((row) => row.toPublicMap()).toList(),
      'findings': findings.map((finding) => finding.toPublicMap()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Release Qualification Preflight')
      ..writeln()
      ..writeln('| Area | Status |')
      ..writeln('| --- | --- |')
      ..writeln('| Mode | `${mode.stableId}` |')
      ..writeln('| Public ready | `$publicReady` |')
      ..writeln('| Dispatch ready | `$dispatchReady` |')
      ..writeln()
      ..writeln('## Qualification Rows')
      ..writeln()
      ..writeln(
        '| Profile | Package | Artifact | SHA256 | Device class | '
        'Evidence | Device model | OS version | Result | Notes |',
      )
      ..writeln(
        '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |',
      );

    for (final row in rows) {
      buffer.writeln(
        '| ${_md(row.profileId)} | ${_md(row.packageId)} | '
        '${_md(row.filename)} | `${_shortSha(row.sha256)}` | '
        '`${row.deviceClass.stableId}` | `${row.evidenceType.stableId}` | '
        '${_md(row.deviceModel)} | ${_md(row.osVersion)} | '
        '`${row.result.stableId}` | ${_md(row.notes)} |',
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
      ..writeln(
        '| Code | Profile | Artifact | Device class | Blocking | Message |',
      )
      ..writeln('| --- | --- | --- | --- | --- | --- |');
    for (final finding in findings) {
      buffer.writeln(
        '| `${finding.code.stableId}` | `${finding.profileId ?? ''}` | '
        '`${finding.filename ?? ''}` | '
        '`${finding.deviceClass?.stableId ?? ''}` | '
        '`${finding.blocking}` | ${_md(finding.message)} |',
      );
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props => [schemaVersion, mode, rows, findings];
}

class AiroReleaseQualificationPreflightRequest extends Equatable {
  AiroReleaseQualificationPreflightRequest({
    required this.mode,
    required Iterable<AiroReleaseArtifactEvidence> artifacts,
    required Iterable<AiroReleaseQualificationCheck> checks,
    required Iterable<AiroReleaseQualificationWaiver> waivers,
  }) : artifacts = List.unmodifiable(artifacts),
       checks = List.unmodifiable(checks),
       waivers = List.unmodifiable(waivers);

  final AiroReleaseQualificationMode mode;
  final List<AiroReleaseArtifactEvidence> artifacts;
  final List<AiroReleaseQualificationCheck> checks;
  final List<AiroReleaseQualificationWaiver> waivers;

  @override
  List<Object?> get props => [mode, artifacts, checks, waivers];
}

class AiroReleaseQualificationPreflightRunner {
  const AiroReleaseQualificationPreflightRunner({
    this.matrix = const _DefaultReleaseMatrixProvider(),
  });

  final AiroReleaseMatrixProvider matrix;

  static const List<AiroReleaseQualificationRequirement> requirements = [
    AiroReleaseQualificationRequirement(
      profileId: 'iptv-standalone',
      deviceClass: AiroReleaseDeviceClass.androidPhone,
      evidenceType: AiroReleaseQualificationEvidenceType.physicalDevice,
    ),
    AiroReleaseQualificationRequirement(
      profileId: 'iptv-standalone',
      deviceClass: AiroReleaseDeviceClass.androidTablet,
      evidenceType: AiroReleaseQualificationEvidenceType.wideLayout,
    ),
    AiroReleaseQualificationRequirement(
      profileId: 'mobile-streaming',
      deviceClass: AiroReleaseDeviceClass.androidPhone,
      evidenceType: AiroReleaseQualificationEvidenceType.physicalDevice,
    ),
    AiroReleaseQualificationRequirement(
      profileId: 'mobile-streaming',
      deviceClass: AiroReleaseDeviceClass.androidTablet,
      evidenceType: AiroReleaseQualificationEvidenceType.wideLayout,
    ),
    AiroReleaseQualificationRequirement(
      profileId: 'tv',
      deviceClass: AiroReleaseDeviceClass.androidTv,
      evidenceType: AiroReleaseQualificationEvidenceType.physicalDevice,
    ),
    AiroReleaseQualificationRequirement(
      profileId: 'tv',
      deviceClass: AiroReleaseDeviceClass.fireTv,
      evidenceType: AiroReleaseQualificationEvidenceType.physicalDevice,
    ),
  ];

  AiroReleaseQualificationPreflight run(
    AiroReleaseQualificationPreflightRequest request,
  ) {
    final releaseMatrix = matrix.releaseMatrix();
    final findings = <AiroReleaseQualificationFinding>[];
    final rows = <AiroReleaseQualificationRow>[];

    for (final artifact in request.artifacts.where((item) => item.isApk)) {
      AiroReleaseProfile profile;
      try {
        profile = releaseMatrix.profileById(artifact.profileId);
      } on StateError {
        findings.add(
          AiroReleaseQualificationFinding(
            code: AiroReleaseQualificationFindingCode.unknownProfile,
            profileId: artifact.profileId,
            filename: artifact.filename,
            message:
                'Release qualification artifact references an unknown profile.',
          ),
        );
        continue;
      }

      if (artifact.filename.trim().isEmpty) {
        findings.add(
          AiroReleaseQualificationFinding(
            code: AiroReleaseQualificationFindingCode.missingArtifactFilename,
            profileId: artifact.profileId,
            message: 'Release artifact filename is required.',
          ),
        );
      }
      if (artifact.sha256.trim().isEmpty) {
        findings.add(
          AiroReleaseQualificationFinding(
            code: AiroReleaseQualificationFindingCode.missingArtifactChecksum,
            profileId: artifact.profileId,
            filename: artifact.filename,
            message: 'Release artifact checksum is required for qualification.',
          ),
        );
      }

      final profileRequirements = requirements.where(
        (requirement) => requirement.profileId == profile.id,
      );
      for (final requirement in profileRequirements) {
        final row = _rowForRequirement(
          artifact: artifact,
          requirement: requirement,
          checks: request.checks,
          waivers: request.waivers,
          findings: findings,
          packageId: artifact.packageId.trim().isEmpty
              ? profile.packageId
              : artifact.packageId,
        );
        rows.add(row);
      }
    }

    return AiroReleaseQualificationPreflight(
      mode: request.mode,
      rows: rows,
      findings: findings,
    );
  }

  AiroReleaseQualificationRow _rowForRequirement({
    required AiroReleaseArtifactEvidence artifact,
    required AiroReleaseQualificationRequirement requirement,
    required Iterable<AiroReleaseQualificationCheck> checks,
    required Iterable<AiroReleaseQualificationWaiver> waivers,
    required List<AiroReleaseQualificationFinding> findings,
    required String packageId,
  }) {
    final check = checks.where((candidate) {
      return _same(candidate.profileId, artifact.profileId) &&
          _same(candidate.filename, artifact.filename) &&
          candidate.deviceClass == requirement.deviceClass &&
          candidate.evidenceType == requirement.evidenceType;
    }).firstOrNull;

    if (check != null) {
      if (check.result != AiroReleaseQualificationResult.passed) {
        findings.add(
          AiroReleaseQualificationFinding(
            code: AiroReleaseQualificationFindingCode.failedEvidence,
            profileId: artifact.profileId,
            filename: artifact.filename,
            deviceClass: requirement.deviceClass,
            message:
                'Qualification evidence exists but did not pass for '
                '${requirement.deviceClass.stableId}.',
          ),
        );
      }
      if (check.deviceModel.trim().isEmpty || check.osVersion.trim().isEmpty) {
        findings.add(
          AiroReleaseQualificationFinding(
            code: AiroReleaseQualificationFindingCode.incompleteEvidenceDevice,
            profileId: artifact.profileId,
            filename: artifact.filename,
            deviceClass: requirement.deviceClass,
            message:
                'Passing qualification evidence must include device model and '
                'OS version.',
          ),
        );
      }
      return AiroReleaseQualificationRow(
        profileId: artifact.profileId,
        packageId: packageId,
        filename: artifact.filename,
        sha256: artifact.sha256,
        deviceClass: requirement.deviceClass,
        evidenceType: requirement.evidenceType,
        result: check.result,
        deviceModel: check.deviceModel,
        osVersion: check.osVersion,
        notes: check.notes,
      );
    }

    final waiver = waivers.where((candidate) {
      final filenameMatches =
          candidate.filename.trim().isEmpty ||
          _same(candidate.filename, artifact.filename);
      return _same(candidate.profileId, artifact.profileId) &&
          filenameMatches &&
          candidate.deviceClass == requirement.deviceClass;
    }).firstOrNull;

    if (waiver != null) {
      if (!waiver.complete) {
        findings.add(
          AiroReleaseQualificationFinding(
            code: AiroReleaseQualificationFindingCode.incompleteWaiver,
            profileId: artifact.profileId,
            filename: artifact.filename,
            deviceClass: requirement.deviceClass,
            message:
                'Qualification waiver must include both reason and approver.',
          ),
        );
      }
      return AiroReleaseQualificationRow(
        profileId: artifact.profileId,
        packageId: packageId,
        filename: artifact.filename,
        sha256: artifact.sha256,
        deviceClass: requirement.deviceClass,
        evidenceType: requirement.evidenceType,
        result: AiroReleaseQualificationResult.waived,
        notes:
            '${waiver.reason.trim()} Approved by ${waiver.approvedBy.trim()}.',
      );
    }

    findings.add(
      AiroReleaseQualificationFinding(
        code: AiroReleaseQualificationFindingCode.missingRequiredEvidence,
        profileId: artifact.profileId,
        filename: artifact.filename,
        deviceClass: requirement.deviceClass,
        message:
            'No passing evidence or approved waiver for '
            '${requirement.deviceClass.stableId}.',
      ),
    );

    return AiroReleaseQualificationRow(
      profileId: artifact.profileId,
      packageId: packageId,
      filename: artifact.filename,
      sha256: artifact.sha256,
      deviceClass: requirement.deviceClass,
      evidenceType: requirement.evidenceType,
      result: AiroReleaseQualificationResult.missing,
      notes: 'No passing evidence or approved waiver.',
    );
  }
}

abstract interface class AiroReleaseMatrixProvider {
  AiroReleaseMatrix releaseMatrix();
}

class _DefaultReleaseMatrixProvider implements AiroReleaseMatrixProvider {
  const _DefaultReleaseMatrixProvider();

  @override
  AiroReleaseMatrix releaseMatrix() => AiroReleaseMatrix.v2Default();
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}

bool _same(String left, String right) {
  return _normalize(left) == _normalize(right);
}

String _normalize(Object value) {
  return value.toString().trim().toLowerCase().replaceAll('_', '-');
}

String _shortSha(String value) {
  return value.length <= 12 ? value : value.substring(0, 12);
}

String _md(String value) {
  return value.replaceAll('|', r'\|').replaceAll('\n', ' ');
}
