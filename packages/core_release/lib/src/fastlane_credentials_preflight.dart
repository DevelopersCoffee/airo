import 'package:equatable/equatable.dart';

import 'release_matrix.dart';

enum AiroFastlaneCredentialTarget {
  googlePlay('google_play'),
  appStoreConnect('app_store_connect');

  const AiroFastlaneCredentialTarget(this.stableId);

  final String stableId;
}

enum AiroFastlaneCredentialFindingCode {
  unknownProfile('unknown_profile'),
  profileNotPlayEligible('profile_not_play_eligible'),
  packageNameMismatch('package_name_mismatch'),
  missingGooglePlayCredential('missing_google_play_credential'),
  iosUploadDeferred('ios_upload_deferred'),
  missingAppleCredential('missing_apple_credential'),
  missingAppleTeam('missing_apple_team'),
  placeholderAppleIdentifier('placeholder_apple_identifier');

  const AiroFastlaneCredentialFindingCode(this.stableId);

  final String stableId;
}

class AiroFastlaneCredentialFinding extends Equatable {
  const AiroFastlaneCredentialFinding({
    required this.target,
    required this.code,
    required this.message,
    this.blocking = true,
  });

  final AiroFastlaneCredentialTarget target;
  final AiroFastlaneCredentialFindingCode code;
  final String message;
  final bool blocking;

  Map<String, Object?> toPublicMap() {
    return {
      'target': target.stableId,
      'code': code.stableId,
      'message': message,
      'blocking': blocking,
    };
  }

  @override
  List<Object?> get props => [target, code, message, blocking];
}

class AiroFastlaneCredentialsPreflightRequest extends Equatable {
  const AiroFastlaneCredentialsPreflightRequest({
    required this.profileId,
    this.environment = const {},
    this.defaultAndroidPackageName = 'io.airo.app.tv',
    this.defaultAndroidCredentialPath =
        'app/android/play-store-credentials.json',
    this.googlePlayCredentialFileExists = false,
    this.defaultAppleAppIdentifier = 'com.developerscoffee.airo',
    this.iosUploadInScope = false,
  });

  final String profileId;
  final Map<String, String> environment;
  final String defaultAndroidPackageName;
  final String defaultAndroidCredentialPath;
  final bool googlePlayCredentialFileExists;
  final String defaultAppleAppIdentifier;
  final bool iosUploadInScope;

  @override
  List<Object?> get props => [
    profileId,
    environment,
    defaultAndroidPackageName,
    defaultAndroidCredentialPath,
    googlePlayCredentialFileExists,
    defaultAppleAppIdentifier,
    iosUploadInScope,
  ];
}

class AiroFastlaneCredentialsPreflight extends Equatable {
  AiroFastlaneCredentialsPreflight({
    required this.profileId,
    required this.expectedAndroidPackageName,
    required this.androidPackageName,
    required this.googlePlayCredentialPresent,
    required this.googlePlayCredentialSource,
    required this.appleAppIdentifier,
    required this.iosUploadInScope,
    required Iterable<AiroFastlaneCredentialFinding> findings,
    this.schemaVersion = kAiroReleaseMatrixSchemaVersion,
  }) : findings = List.unmodifiable(findings);

  final String schemaVersion;
  final String profileId;
  final String? expectedAndroidPackageName;
  final String androidPackageName;
  final bool googlePlayCredentialPresent;
  final String? googlePlayCredentialSource;
  final String appleAppIdentifier;
  final bool iosUploadInScope;
  final List<AiroFastlaneCredentialFinding> findings;

  bool get googlePlayReady {
    return !findings.any(
      (finding) =>
          finding.target == AiroFastlaneCredentialTarget.googlePlay &&
          finding.blocking,
    );
  }

  bool get appStoreConnectReady {
    return iosUploadInScope &&
        !findings.any(
          (finding) =>
              finding.target == AiroFastlaneCredentialTarget.appStoreConnect &&
              finding.blocking,
        );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'profileId': profileId,
      'googlePlay': {
        'ready': googlePlayReady,
        'expectedPackageName': expectedAndroidPackageName,
        'effectivePackageName': androidPackageName,
        'credentialPresent': googlePlayCredentialPresent,
        'credentialSource': googlePlayCredentialSource,
      },
      'appStoreConnect': {
        'ready': appStoreConnectReady,
        'uploadInScope': iosUploadInScope,
        'appIdentifier': appleAppIdentifier,
      },
      'findings': findings.map((finding) => finding.toPublicMap()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Fastlane Credentials Preflight')
      ..writeln()
      ..writeln('| Area | Status |')
      ..writeln('| --- | --- |')
      ..writeln('| Profile | `$profileId` |')
      ..writeln('| Google Play | ${googlePlayReady ? 'ready' : 'blocked'} |')
      ..writeln(
        '| Google Play package | `$androidPackageName`'
        '${expectedAndroidPackageName == null ? '' : ' expected `$expectedAndroidPackageName`'} |',
      )
      ..writeln(
        '| Google Play credential | '
        '${googlePlayCredentialPresent ? 'present' : 'missing'} |',
      )
      ..writeln(
        '| App Store Connect | ${appStoreConnectReady ? 'ready' : 'not ready'} |',
      )
      ..writeln('| iOS upload in scope | `$iosUploadInScope` |')
      ..writeln('| App identifier | `$appleAppIdentifier` |')
      ..writeln();

    if (findings.isEmpty) {
      buffer.writeln('No findings.');
      return buffer.toString();
    }

    buffer
      ..writeln('## Findings')
      ..writeln()
      ..writeln('| Target | Code | Blocking | Message |')
      ..writeln('| --- | --- | --- | --- |');
    for (final finding in findings) {
      buffer.writeln(
        '| `${finding.target.stableId}` | `${finding.code.stableId}` | '
        '`${finding.blocking}` | ${finding.message} |',
      );
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    profileId,
    expectedAndroidPackageName,
    androidPackageName,
    googlePlayCredentialPresent,
    googlePlayCredentialSource,
    appleAppIdentifier,
    iosUploadInScope,
    findings,
  ];
}

class AiroFastlaneCredentialsPreflightRunner {
  const AiroFastlaneCredentialsPreflightRunner({required this.matrix});

  static const List<String> appleCredentialVariables = [
    'MATCH_PASSWORD',
    'ASC_KEY_ID',
    'ASC_ISSUER_ID',
    'ASC_KEY_CONTENT',
  ];

  final AiroReleaseMatrix matrix;

  AiroFastlaneCredentialsPreflight run(
    AiroFastlaneCredentialsPreflightRequest request,
  ) {
    final findings = <AiroFastlaneCredentialFinding>[];
    final environment = request.environment;
    final androidPackageName = _firstConfigured(
      environment,
      'SUPPLY_PACKAGE_NAME',
      fallback: request.defaultAndroidPackageName,
    );
    final appleAppIdentifier = _firstConfigured(
      environment,
      'APP_IDENTIFIER',
      fallback: request.defaultAppleAppIdentifier,
    );

    AiroReleaseProfile? profile;
    try {
      profile = matrix.profileById(request.profileId);
    } on StateError {
      findings.add(
        AiroFastlaneCredentialFinding(
          target: AiroFastlaneCredentialTarget.googlePlay,
          code: AiroFastlaneCredentialFindingCode.unknownProfile,
          message: 'Unknown release profile: ${request.profileId}.',
        ),
      );
    }

    final expectedAndroidPackageName = profile?.packageId;
    final googlePlayRule = profile?.distributionFor(
      AiroReleaseDistributionChannel.googlePlay,
    );
    final playEligible =
        profile != null &&
        profile.supportsArtifact(AiroReleaseArtifactKind.playStoreAab) &&
        googlePlayRule != null &&
        googlePlayRule.status != AiroReleaseDistributionStatus.deferred &&
        googlePlayRule.status != AiroReleaseDistributionStatus.unsupported &&
        googlePlayRule.status != AiroReleaseDistributionStatus.validationOnly;

    if (profile != null && !playEligible) {
      findings.add(
        AiroFastlaneCredentialFinding(
          target: AiroFastlaneCredentialTarget.googlePlay,
          code: AiroFastlaneCredentialFindingCode.profileNotPlayEligible,
          message: 'Profile ${profile.id} is not eligible for Play upload.',
        ),
      );
    }

    if (expectedAndroidPackageName != null &&
        androidPackageName != expectedAndroidPackageName) {
      findings.add(
        AiroFastlaneCredentialFinding(
          target: AiroFastlaneCredentialTarget.googlePlay,
          code: AiroFastlaneCredentialFindingCode.packageNameMismatch,
          message:
              'SUPPLY_PACKAGE_NAME resolves to $androidPackageName but '
              '${request.profileId} expects $expectedAndroidPackageName.',
        ),
      );
    }

    final googleCredentialSource = _googleCredentialSource(
      environment: environment,
      credentialFileExists: request.googlePlayCredentialFileExists,
    );
    if (googleCredentialSource == null) {
      findings.add(
        const AiroFastlaneCredentialFinding(
          target: AiroFastlaneCredentialTarget.googlePlay,
          code: AiroFastlaneCredentialFindingCode.missingGooglePlayCredential,
          message:
              'Set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON or provide the redacted '
              'Fastlane service-account file before running Play upload.',
        ),
      );
    }

    if (!request.iosUploadInScope) {
      findings.add(
        const AiroFastlaneCredentialFinding(
          target: AiroFastlaneCredentialTarget.appStoreConnect,
          code: AiroFastlaneCredentialFindingCode.iosUploadDeferred,
          blocking: false,
          message:
              'iOS upload is deferred for this release wave; App Store Connect '
              'credentials are tracked but not required for Android TV upload.',
        ),
      );
    }

    for (final variable in appleCredentialVariables) {
      if (!_hasValue(environment, variable)) {
        findings.add(
          AiroFastlaneCredentialFinding(
            target: AiroFastlaneCredentialTarget.appStoreConnect,
            code: AiroFastlaneCredentialFindingCode.missingAppleCredential,
            blocking: request.iosUploadInScope,
            message:
                'Set $variable before running TestFlight/App Store upload.',
          ),
        );
      }
    }

    if (!_hasValue(environment, 'TEAM_ID')) {
      findings.add(
        AiroFastlaneCredentialFinding(
          target: AiroFastlaneCredentialTarget.appStoreConnect,
          code: AiroFastlaneCredentialFindingCode.missingAppleTeam,
          blocking: request.iosUploadInScope,
          message: 'Set TEAM_ID before running iOS signing or upload lanes.',
        ),
      );
    }

    if (_looksPlaceholder(appleAppIdentifier)) {
      findings.add(
        AiroFastlaneCredentialFinding(
          target: AiroFastlaneCredentialTarget.appStoreConnect,
          code: AiroFastlaneCredentialFindingCode.placeholderAppleIdentifier,
          blocking: request.iosUploadInScope,
          message: 'APP_IDENTIFIER must be a real bundle identifier.',
        ),
      );
    }

    return AiroFastlaneCredentialsPreflight(
      profileId: request.profileId,
      expectedAndroidPackageName: expectedAndroidPackageName,
      androidPackageName: androidPackageName,
      googlePlayCredentialPresent: googleCredentialSource != null,
      googlePlayCredentialSource: googleCredentialSource,
      appleAppIdentifier: appleAppIdentifier,
      iosUploadInScope: request.iosUploadInScope,
      findings: findings,
    );
  }

  String _firstConfigured(
    Map<String, String> environment,
    String variable, {
    required String fallback,
  }) {
    final value = environment[variable]?.trim();
    if (value == null || value.isEmpty) {
      return fallback;
    }
    return value;
  }

  String? _googleCredentialSource({
    required Map<String, String> environment,
    required bool credentialFileExists,
  }) {
    if (_hasValue(environment, 'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON')) {
      return 'env:GOOGLE_PLAY_SERVICE_ACCOUNT_JSON';
    }
    if (_hasValue(environment, 'PLAY_STORE_CREDENTIALS')) {
      return 'env:PLAY_STORE_CREDENTIALS';
    }
    if (credentialFileExists) {
      return 'file:play-store-credentials.json';
    }
    return null;
  }

  bool _hasValue(Map<String, String> environment, String variable) {
    final value = environment[variable];
    return value != null && value.trim().isNotEmpty;
  }

  bool _looksPlaceholder(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('your-') ||
        normalized.contains('example') ||
        normalized.contains('placeholder') ||
        normalized.contains('todo');
  }
}
