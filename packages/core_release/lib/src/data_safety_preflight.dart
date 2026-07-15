import 'package:equatable/equatable.dart';

import 'release_matrix.dart';

enum AiroDataSafetyTarget {
  googlePlayDataSafety('google_play_data_safety'),
  appStorePrivacy('app_store_privacy');

  const AiroDataSafetyTarget(this.stableId);

  final String stableId;
}

enum AiroDataSafetyFindingCode {
  unknownProfile('unknown_profile'),
  profileNotStoreEligible('profile_not_store_eligible'),
  analyticsSdkPresent('analytics_sdk_present'),
  crashlyticsSdkPresent('crashlytics_sdk_present'),
  advertisingSdkPresent('advertising_sdk_present'),
  sensitivePermissionPresent('sensitive_permission_present'),
  appStorePrivacyDeferred('app_store_privacy_deferred'),
  consoleSubmissionRequired('console_submission_required'),
  localDataDeclarationChanged('local_data_declaration_changed');

  const AiroDataSafetyFindingCode(this.stableId);

  final String stableId;
}

class AiroDataSafetyFinding extends Equatable {
  const AiroDataSafetyFinding({
    required this.target,
    required this.code,
    required this.message,
    this.blocking = true,
  });

  final AiroDataSafetyTarget target;
  final AiroDataSafetyFindingCode code;
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

class AiroDataSafetyDeclaration extends Equatable {
  const AiroDataSafetyDeclaration({
    required this.dataType,
    required this.collected,
    required this.shared,
    required this.purpose,
    required this.notes,
  });

  final String dataType;
  final String collected;
  final bool shared;
  final String purpose;
  final String notes;

  Map<String, Object?> toPublicMap() {
    return {
      'dataType': dataType,
      'collected': collected,
      'shared': shared,
      'purpose': purpose,
      'notes': notes,
    };
  }

  @override
  List<Object?> get props => [dataType, collected, shared, purpose, notes];
}

class AiroDataSafetyPreflightRequest extends Equatable {
  const AiroDataSafetyPreflightRequest({
    required this.profileId,
    this.analyticsSdkPresent = false,
    this.crashlyticsSdkPresent = false,
    this.advertisingSdkPresent = false,
    this.sensitiveAndroidPermissions = const {},
    this.localPlaylistUrls = true,
    this.localPreferences = true,
    this.localPlaybackState = true,
    this.accountRequiredForPlayback = false,
    this.appStorePrivacyInScope = false,
  });

  final String profileId;
  final bool analyticsSdkPresent;
  final bool crashlyticsSdkPresent;
  final bool advertisingSdkPresent;
  final Set<String> sensitiveAndroidPermissions;
  final bool localPlaylistUrls;
  final bool localPreferences;
  final bool localPlaybackState;
  final bool accountRequiredForPlayback;
  final bool appStorePrivacyInScope;

  @override
  List<Object?> get props => [
    profileId,
    analyticsSdkPresent,
    crashlyticsSdkPresent,
    advertisingSdkPresent,
    sensitiveAndroidPermissions,
    localPlaylistUrls,
    localPreferences,
    localPlaybackState,
    accountRequiredForPlayback,
    appStorePrivacyInScope,
  ];
}

class AiroDataSafetyPreflight extends Equatable {
  AiroDataSafetyPreflight({
    required this.profileId,
    required this.packageId,
    required this.displayName,
    required this.analyticsSdkPresent,
    required this.crashlyticsSdkPresent,
    required this.advertisingSdkPresent,
    required Iterable<String> sensitiveAndroidPermissions,
    required this.localPlaylistUrls,
    required this.localPreferences,
    required this.localPlaybackState,
    required this.accountRequiredForPlayback,
    required this.appStorePrivacyInScope,
    required Iterable<AiroDataSafetyDeclaration> declarations,
    required Iterable<AiroDataSafetyFinding> findings,
    this.schemaVersion = kAiroReleaseMatrixSchemaVersion,
  }) : sensitiveAndroidPermissions = Set.unmodifiable(
         sensitiveAndroidPermissions,
       ),
       declarations = List.unmodifiable(declarations),
       findings = List.unmodifiable(findings);

  final String schemaVersion;
  final String profileId;
  final String? packageId;
  final String displayName;
  final bool analyticsSdkPresent;
  final bool crashlyticsSdkPresent;
  final bool advertisingSdkPresent;
  final Set<String> sensitiveAndroidPermissions;
  final bool localPlaylistUrls;
  final bool localPreferences;
  final bool localPlaybackState;
  final bool accountRequiredForPlayback;
  final bool appStorePrivacyInScope;
  final List<AiroDataSafetyDeclaration> declarations;
  final List<AiroDataSafetyFinding> findings;

  bool get readyForConsoleEntry {
    return !findings.any((finding) => finding.blocking);
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'profileId': profileId,
      'packageId': packageId,
      'displayName': displayName,
      'sourceSignals': {
        'analyticsSdkPresent': analyticsSdkPresent,
        'crashlyticsSdkPresent': crashlyticsSdkPresent,
        'advertisingSdkPresent': advertisingSdkPresent,
        'sensitiveAndroidPermissions': sensitiveAndroidPermissions.toList(),
        'localPlaylistUrls': localPlaylistUrls,
        'localPreferences': localPreferences,
        'localPlaybackState': localPlaybackState,
        'accountRequiredForPlayback': accountRequiredForPlayback,
      },
      'googlePlayDataSafety': {
        'readyForConsoleEntry': readyForConsoleEntry,
        'consoleSubmissionRequired': true,
      },
      'appStorePrivacy': {
        'inScope': appStorePrivacyInScope,
        'consoleSubmissionRequired': appStorePrivacyInScope,
      },
      'declarations': declarations
          .map((declaration) => declaration.toPublicMap())
          .toList(),
      'findings': findings.map((finding) => finding.toPublicMap()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Data Safety Preflight')
      ..writeln()
      ..writeln('| Area | Value |')
      ..writeln('| --- | --- |')
      ..writeln('| Profile | `$profileId` |')
      ..writeln('| Package | `${packageId ?? 'unknown'}` |')
      ..writeln('| Product | $displayName |')
      ..writeln('| Ready for console entry | `$readyForConsoleEntry` |')
      ..writeln('| Analytics SDK present | `$analyticsSdkPresent` |')
      ..writeln('| Crashlytics SDK present | `$crashlyticsSdkPresent` |')
      ..writeln('| Advertising SDK present | `$advertisingSdkPresent` |')
      ..writeln(
        '| Sensitive Android permissions | `${sensitiveAndroidPermissions.join(', ')}` |',
      )
      ..writeln('| App Store Privacy in scope | `$appStorePrivacyInScope` |')
      ..writeln()
      ..writeln(
        'Final Play Data Safety and App Privacy forms must still be submitted '
        'by a maintainer with store-console access.',
      )
      ..writeln()
      ..writeln('## Declarations')
      ..writeln()
      ..writeln('| Data type | Collected | Shared | Purpose | Notes |')
      ..writeln('| --- | --- | --- | --- | --- |');

    for (final declaration in declarations) {
      buffer.writeln(
        '| ${declaration.dataType} | ${declaration.collected} | '
        '${declaration.shared ? 'Yes' : 'No'} | ${declaration.purpose} | '
        '${declaration.notes} |',
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
    packageId,
    displayName,
    analyticsSdkPresent,
    crashlyticsSdkPresent,
    advertisingSdkPresent,
    sensitiveAndroidPermissions,
    localPlaylistUrls,
    localPreferences,
    localPlaybackState,
    accountRequiredForPlayback,
    appStorePrivacyInScope,
    declarations,
    findings,
  ];
}

class AiroDataSafetyPreflightRunner {
  const AiroDataSafetyPreflightRunner({required this.matrix});

  static const Set<String> sensitivePermissionNames = {
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.CAMERA',
    'android.permission.RECORD_AUDIO',
    'android.permission.READ_CONTACTS',
    'android.permission.WRITE_CONTACTS',
    'android.permission.READ_MEDIA_IMAGES',
    'android.permission.READ_MEDIA_VIDEO',
    'android.permission.READ_MEDIA_AUDIO',
    'android.permission.READ_EXTERNAL_STORAGE',
    'android.permission.WRITE_EXTERNAL_STORAGE',
    'com.google.android.gms.permission.AD_ID',
  };

  final AiroReleaseMatrix matrix;

  AiroDataSafetyPreflight run(AiroDataSafetyPreflightRequest request) {
    final findings = <AiroDataSafetyFinding>[];
    AiroReleaseProfile? profile;
    try {
      profile = matrix.profileById(request.profileId);
    } on StateError {
      findings.add(
        AiroDataSafetyFinding(
          target: AiroDataSafetyTarget.googlePlayDataSafety,
          code: AiroDataSafetyFindingCode.unknownProfile,
          message: 'Unknown release profile: ${request.profileId}.',
        ),
      );
    }

    final googlePlayRule = profile?.distributionFor(
      AiroReleaseDistributionChannel.googlePlay,
    );
    if (profile != null &&
        (googlePlayRule == null ||
            googlePlayRule.status == AiroReleaseDistributionStatus.deferred ||
            googlePlayRule.status ==
                AiroReleaseDistributionStatus.unsupported ||
            googlePlayRule.status ==
                AiroReleaseDistributionStatus.validationOnly)) {
      findings.add(
        AiroDataSafetyFinding(
          target: AiroDataSafetyTarget.googlePlayDataSafety,
          code: AiroDataSafetyFindingCode.profileNotStoreEligible,
          message:
              'Profile ${profile.id} is not in scope for Play Data Safety.',
        ),
      );
    }

    findings.add(
      const AiroDataSafetyFinding(
        target: AiroDataSafetyTarget.googlePlayDataSafety,
        code: AiroDataSafetyFindingCode.consoleSubmissionRequired,
        blocking: false,
        message:
            'Google Play Data Safety still requires maintainer submission in '
            'Play Console.',
      ),
    );

    if (!request.appStorePrivacyInScope) {
      findings.add(
        const AiroDataSafetyFinding(
          target: AiroDataSafetyTarget.appStorePrivacy,
          code: AiroDataSafetyFindingCode.appStorePrivacyDeferred,
          blocking: false,
          message:
              'App Store Privacy labels are deferred until iOS/tvOS enters '
              'release scope.',
        ),
      );
    } else {
      findings.add(
        const AiroDataSafetyFinding(
          target: AiroDataSafetyTarget.appStorePrivacy,
          code: AiroDataSafetyFindingCode.consoleSubmissionRequired,
          blocking: false,
          message:
              'App Store Privacy labels still require maintainer submission in '
              'App Store Connect.',
        ),
      );
    }

    if (request.analyticsSdkPresent) {
      findings.add(
        const AiroDataSafetyFinding(
          target: AiroDataSafetyTarget.googlePlayDataSafety,
          code: AiroDataSafetyFindingCode.analyticsSdkPresent,
          message:
              'Analytics SDK is present; declare app activity/device data or '
              'remove the SDK before submission.',
        ),
      );
    }
    if (request.crashlyticsSdkPresent) {
      findings.add(
        const AiroDataSafetyFinding(
          target: AiroDataSafetyTarget.googlePlayDataSafety,
          code: AiroDataSafetyFindingCode.crashlyticsSdkPresent,
          message:
              'Crash-reporting SDK is present; declare diagnostics collection '
              'or remove the SDK before submission.',
        ),
      );
    }
    if (request.advertisingSdkPresent) {
      findings.add(
        const AiroDataSafetyFinding(
          target: AiroDataSafetyTarget.googlePlayDataSafety,
          code: AiroDataSafetyFindingCode.advertisingSdkPresent,
          message:
              'Advertising SDK is present; declare ads/tracking data or remove '
              'the SDK before submission.',
        ),
      );
    }

    for (final permission in request.sensitiveAndroidPermissions) {
      findings.add(
        AiroDataSafetyFinding(
          target: AiroDataSafetyTarget.googlePlayDataSafety,
          code: AiroDataSafetyFindingCode.sensitivePermissionPresent,
          message:
              'Sensitive TV manifest permission detected: $permission. Update '
              'Data Safety declarations or remove the permission.',
        ),
      );
    }

    if (!request.localPlaylistUrls ||
        !request.localPreferences ||
        !request.localPlaybackState ||
        request.accountRequiredForPlayback) {
      findings.add(
        const AiroDataSafetyFinding(
          target: AiroDataSafetyTarget.googlePlayDataSafety,
          code: AiroDataSafetyFindingCode.localDataDeclarationChanged,
          message:
              'Local-only TV data assumptions changed; update the worksheet and '
              'privacy policy before submission.',
        ),
      );
    }

    return AiroDataSafetyPreflight(
      profileId: request.profileId,
      packageId: profile?.packageId,
      displayName: profile?.displayName ?? request.profileId,
      analyticsSdkPresent: request.analyticsSdkPresent,
      crashlyticsSdkPresent: request.crashlyticsSdkPresent,
      advertisingSdkPresent: request.advertisingSdkPresent,
      sensitiveAndroidPermissions: request.sensitiveAndroidPermissions,
      localPlaylistUrls: request.localPlaylistUrls,
      localPreferences: request.localPreferences,
      localPlaybackState: request.localPlaybackState,
      accountRequiredForPlayback: request.accountRequiredForPlayback,
      appStorePrivacyInScope: request.appStorePrivacyInScope,
      declarations: _declarations(request),
      findings: findings,
    );
  }

  List<AiroDataSafetyDeclaration> _declarations(
    AiroDataSafetyPreflightRequest request,
  ) {
    return [
      AiroDataSafetyDeclaration(
        dataType: 'Personal info',
        collected: request.accountRequiredForPlayback
            ? 'Review required'
            : 'No',
        shared: false,
        purpose: 'Not applicable',
        notes: 'TV IPTV playback does not require account creation.',
      ),
      const AiroDataSafetyDeclaration(
        dataType: 'Location',
        collected: 'No',
        shared: false,
        purpose: 'Not applicable',
        notes: 'No location permission is expected in the TV manifest.',
      ),
      const AiroDataSafetyDeclaration(
        dataType: 'Contacts',
        collected: 'No',
        shared: false,
        purpose: 'Not applicable',
        notes: 'No contacts permission is expected in the TV manifest.',
      ),
      const AiroDataSafetyDeclaration(
        dataType: 'Photos, videos, or audio files',
        collected: 'No',
        shared: false,
        purpose: 'Not applicable',
        notes:
            'No camera, microphone, media library, or external storage '
            'permission is expected for TV.',
      ),
      const AiroDataSafetyDeclaration(
        dataType: 'Financial info',
        collected: 'No',
        shared: false,
        purpose: 'Not applicable',
        notes: 'No purchases or payment flow in the TV release profile.',
      ),
      AiroDataSafetyDeclaration(
        dataType: 'App activity',
        collected: request.analyticsSdkPresent
            ? 'Review required'
            : 'No app-owned external collection',
        shared: false,
        purpose: 'App functionality',
        notes:
            'Playlist, preferences, and playback state are local-only unless '
            'analytics is enabled.',
      ),
      AiroDataSafetyDeclaration(
        dataType: 'App info and performance',
        collected: request.crashlyticsSdkPresent
            ? 'Review required'
            : 'No app-owned external collection',
        shared: false,
        purpose: 'Diagnostics',
        notes:
            'Crash logs are not collected by the developer unless a crash SDK '
            'is enabled.',
      ),
      AiroDataSafetyDeclaration(
        dataType: 'Device or other IDs',
        collected: request.advertisingSdkPresent
            ? 'Review required'
            : 'No app-owned external collection',
        shared: false,
        purpose: 'Not applicable',
        notes: 'No advertising ID SDK or permission is expected for TV.',
      ),
      AiroDataSafetyDeclaration(
        dataType: 'IPTV playlist URLs',
        collected: request.localPlaylistUrls ? 'Local only' : 'Review required',
        shared: false,
        purpose: 'App functionality',
        notes: 'User-provided playlist URLs are stored on device for playback.',
      ),
      AiroDataSafetyDeclaration(
        dataType: 'Playback preferences and state',
        collected: request.localPreferences && request.localPlaybackState
            ? 'Local only'
            : 'Review required',
        shared: false,
        purpose: 'App functionality',
        notes: 'Local app data is removed by clearing storage or uninstalling.',
      ),
    ];
  }
}
