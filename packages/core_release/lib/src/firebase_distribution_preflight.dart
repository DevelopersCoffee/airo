import 'package:equatable/equatable.dart';

import 'release_matrix.dart';

enum AiroFirebaseDistributionMode {
  none('none'),
  upload('upload');

  const AiroFirebaseDistributionMode(this.stableId);

  final String stableId;

  static AiroFirebaseDistributionMode parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'none' || 'off' || 'disabled' => none,
      'upload' || 'enabled' => upload,
      _ => throw ArgumentError.value(
        value,
        'value',
        'Unsupported Firebase distribution mode.',
      ),
    };
  }
}

enum AiroFirebaseDistributionFindingCode {
  distributionDisabled('distribution_disabled'),
  unknownProfile('unknown_profile'),
  missingFirebaseAppId('missing_firebase_app_id'),
  placeholderFirebaseAppId('placeholder_firebase_app_id'),
  missingTesterGroups('missing_tester_groups'),
  missingServiceAccount('missing_service_account');

  const AiroFirebaseDistributionFindingCode(this.stableId);

  final String stableId;
}

class AiroFirebaseDistributionTarget extends Equatable {
  const AiroFirebaseDistributionTarget({
    required this.profileId,
    required this.packageId,
    required this.firebaseAppId,
    required this.testerGroups,
  });

  final String profileId;
  final String packageId;
  final String firebaseAppId;
  final String testerGroups;

  bool get hasFirebaseAppId => firebaseAppId.trim().isNotEmpty;
  bool get hasTesterGroups => testerGroups.trim().isNotEmpty;
  bool get firebaseAppIdLooksPlaceholder {
    final normalized = firebaseAppId.trim().toLowerCase();
    return normalized.contains('todo') ||
        normalized.contains('your_') ||
        normalized.contains('placeholder') ||
        normalized == 'firebase_app_id';
  }

  Map<String, Object?> toPublicMap() {
    return {
      'profileId': profileId,
      'packageId': packageId,
      'firebaseAppIdPresent': hasFirebaseAppId,
      if (hasFirebaseAppId)
        'firebaseAppId': AiroFirebaseDistributionPreflightRunner.redactAppId(
          firebaseAppId,
        ),
      'testerGroupsPresent': hasTesterGroups,
      if (hasTesterGroups) 'testerGroupCount': _testerGroupCount(testerGroups),
    };
  }

  static int _testerGroupCount(String value) {
    return value
        .split(',')
        .map((group) => group.trim())
        .where((group) => group.isNotEmpty)
        .length;
  }

  @override
  List<Object?> get props => [
    profileId,
    packageId,
    firebaseAppId,
    testerGroups,
  ];
}

class AiroFirebaseDistributionFinding extends Equatable {
  const AiroFirebaseDistributionFinding({
    required this.code,
    required this.message,
    this.profileId,
    this.blocking = true,
  });

  final AiroFirebaseDistributionFindingCode code;
  final String message;
  final String? profileId;
  final bool blocking;

  Map<String, Object?> toPublicMap() {
    return {
      'code': code.stableId,
      if (profileId != null) 'profileId': profileId,
      'message': message,
      'blocking': blocking,
    };
  }

  @override
  List<Object?> get props => [code, message, profileId, blocking];
}

class AiroFirebaseDistributionPreflightRequest extends Equatable {
  AiroFirebaseDistributionPreflightRequest({
    required this.mode,
    required Iterable<AiroFirebaseDistributionTarget> targets,
    this.serviceAccountPresent = false,
  }) : targets = List.unmodifiable(targets);

  final AiroFirebaseDistributionMode mode;
  final List<AiroFirebaseDistributionTarget> targets;
  final bool serviceAccountPresent;

  @override
  List<Object?> get props => [mode, targets, serviceAccountPresent];
}

class AiroFirebaseDistributionPreflight extends Equatable {
  AiroFirebaseDistributionPreflight({
    required this.mode,
    required this.serviceAccountPresent,
    required Iterable<AiroFirebaseDistributionTarget> targets,
    required Iterable<AiroFirebaseDistributionFinding> findings,
    this.schemaVersion = kAiroReleaseMatrixSchemaVersion,
  }) : targets = List.unmodifiable(targets),
       findings = List.unmodifiable(findings);

  final String schemaVersion;
  final AiroFirebaseDistributionMode mode;
  final bool serviceAccountPresent;
  final List<AiroFirebaseDistributionTarget> targets;
  final List<AiroFirebaseDistributionFinding> findings;

  bool get ready => !findings.any((finding) => finding.blocking);

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'ready': ready,
      'mode': mode.stableId,
      'serviceAccountPresent': serviceAccountPresent,
      'targets': targets.map((target) => target.toPublicMap()).toList(),
      'findings': findings.map((finding) => finding.toPublicMap()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Firebase App Distribution Preflight')
      ..writeln()
      ..writeln('| Area | Status |')
      ..writeln('| --- | --- |')
      ..writeln('| Ready | `$ready` |')
      ..writeln('| Mode | `${mode.stableId}` |')
      ..writeln(
        '| Service account | `${serviceAccountPresent ? 'present' : 'missing'}` |',
      )
      ..writeln()
      ..writeln('## Targets')
      ..writeln()
      ..writeln('| Profile | Package | App ID | Tester groups |')
      ..writeln('| --- | --- | --- | --- |');

    for (final target in targets) {
      buffer.writeln(
        '| `${target.profileId}` | `${target.packageId}` | '
        '${target.hasFirebaseAppId ? 'present' : 'missing'} | '
        '${target.hasTesterGroups ? 'present' : 'missing'} |',
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
      ..writeln('| Code | Profile | Blocking | Message |')
      ..writeln('| --- | --- | --- | --- |');
    for (final finding in findings) {
      buffer.writeln(
        '| `${finding.code.stableId}` | `${finding.profileId ?? ''}` | '
        '`${finding.blocking}` | ${finding.message} |',
      );
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    mode,
    serviceAccountPresent,
    targets,
    findings,
  ];
}

class AiroFirebaseDistributionPreflightRunner {
  const AiroFirebaseDistributionPreflightRunner();

  AiroFirebaseDistributionPreflight run(
    AiroFirebaseDistributionPreflightRequest request,
  ) {
    final findings = <AiroFirebaseDistributionFinding>[];

    if (request.mode == AiroFirebaseDistributionMode.none) {
      findings.add(
        const AiroFirebaseDistributionFinding(
          code: AiroFirebaseDistributionFindingCode.distributionDisabled,
          blocking: false,
          message:
              'Firebase App Distribution upload is disabled; no app IDs, '
              'tester groups, or service account are required.',
        ),
      );
    } else {
      if (!request.serviceAccountPresent) {
        findings.add(
          const AiroFirebaseDistributionFinding(
            code: AiroFirebaseDistributionFindingCode.missingServiceAccount,
            message:
                'Set FIREBASE_SERVICE_ACCOUNT_JSON before enabling Firebase '
                'App Distribution upload.',
          ),
        );
      }
      for (final target in request.targets) {
        if (!target.hasFirebaseAppId) {
          findings.add(
            AiroFirebaseDistributionFinding(
              profileId: target.profileId,
              code: AiroFirebaseDistributionFindingCode.missingFirebaseAppId,
              message:
                  'Provide the Firebase App Distribution app id for '
                  '${target.profileId}.',
            ),
          );
        } else if (target.firebaseAppIdLooksPlaceholder) {
          findings.add(
            AiroFirebaseDistributionFinding(
              profileId: target.profileId,
              code:
                  AiroFirebaseDistributionFindingCode.placeholderFirebaseAppId,
              message:
                  'Firebase app id for ${target.profileId} is still a '
                  'placeholder.',
            ),
          );
        }
        if (!target.hasTesterGroups) {
          findings.add(
            AiroFirebaseDistributionFinding(
              profileId: target.profileId,
              code: AiroFirebaseDistributionFindingCode.missingTesterGroups,
              message:
                  'Provide comma-separated Firebase tester groups for '
                  '${target.profileId}.',
            ),
          );
        }
      }
    }

    return AiroFirebaseDistributionPreflight(
      mode: request.mode,
      serviceAccountPresent: request.serviceAccountPresent,
      targets: request.targets,
      findings: findings,
    );
  }

  static List<AiroFirebaseDistributionTarget> targetsFromReleaseProfiles({
    required AiroReleaseMatrix matrix,
    required Iterable<String> profileIds,
    required Map<String, String> firebaseAppIds,
    required Map<String, String> testerGroups,
  }) {
    final targets = <AiroFirebaseDistributionTarget>[];
    for (final profileId in profileIds) {
      final profile = matrix.profileById(profileId);
      targets.add(
        AiroFirebaseDistributionTarget(
          profileId: profile.id,
          packageId: profile.packageId,
          firebaseAppId: firebaseAppIds[profile.id] ?? '',
          testerGroups: testerGroups[profile.id] ?? '',
        ),
      );
    }
    return List.unmodifiable(targets);
  }

  static String redactAppId(String appId) {
    final trimmed = appId.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.toLowerCase().contains('todo') ||
        trimmed.toLowerCase().contains('placeholder')) {
      return '<placeholder>';
    }
    if (trimmed.length <= 8) return '<redacted>';
    return '${trimmed.substring(0, 2)}...${trimmed.substring(trimmed.length - 4)}';
  }
}
