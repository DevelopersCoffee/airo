import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'release_matrix.dart';

enum AiroFirebaseAndroidClientFindingCode {
  missingExpectedPackage('missing_expected_package'),
  missingGoogleServicesClient('missing_google_services_client'),
  missingFirebaseOptionsBlock('missing_firebase_options_block'),
  placeholderFirebaseOptionsAppId('placeholder_firebase_options_app_id'),
  mismatchedFirebaseOptionsAppId('mismatched_firebase_options_app_id');

  const AiroFirebaseAndroidClientFindingCode(this.stableId);

  final String stableId;
}

class AiroFirebaseAndroidClientFinding extends Equatable {
  const AiroFirebaseAndroidClientFinding({
    required this.packageName,
    required this.code,
    required this.message,
    this.blocking = true,
  });

  final String packageName;
  final AiroFirebaseAndroidClientFindingCode code;
  final String message;
  final bool blocking;

  Map<String, Object?> toPublicMap() {
    return {
      'packageName': packageName,
      'code': code.stableId,
      'message': message,
      'blocking': blocking,
    };
  }

  @override
  List<Object?> get props => [packageName, code, message, blocking];
}

class AiroFirebaseAndroidClientExpectation extends Equatable {
  const AiroFirebaseAndroidClientExpectation({
    required this.packageName,
    required this.firebaseOptionsName,
  });

  final String packageName;
  final String firebaseOptionsName;

  @override
  List<Object?> get props => [packageName, firebaseOptionsName];
}

class AiroFirebaseAndroidClientConfig extends Equatable {
  const AiroFirebaseAndroidClientConfig({
    required this.packageName,
    required this.mobileSdkAppId,
  });

  final String packageName;
  final String mobileSdkAppId;

  Map<String, Object?> toPublicMap() {
    return {
      'packageName': packageName,
      'mobileSdkAppId': AiroFirebaseAndroidClientPreflightRunner.redactAppId(
        mobileSdkAppId,
      ),
    };
  }

  @override
  List<Object?> get props => [packageName, mobileSdkAppId];
}

class AiroFirebaseAndroidOptionsConfig extends Equatable {
  const AiroFirebaseAndroidOptionsConfig({
    required this.optionsName,
    required this.appId,
  });

  final String optionsName;
  final String appId;

  bool get configured =>
      appId.trim().isNotEmpty &&
      !appId.toUpperCase().contains('TODO') &&
      !appId.toUpperCase().contains('YOUR_') &&
      !appId.toLowerCase().contains('placeholder');

  Map<String, Object?> toPublicMap() {
    return {
      'optionsName': optionsName,
      'configured': configured,
      'appId': AiroFirebaseAndroidClientPreflightRunner.redactAppId(appId),
    };
  }

  @override
  List<Object?> get props => [optionsName, appId];
}

class AiroFirebaseAndroidClientPreflightRequest extends Equatable {
  AiroFirebaseAndroidClientPreflightRequest({
    required Iterable<AiroFirebaseAndroidClientExpectation> expectedClients,
    required this.googleServicesJson,
    required this.firebaseOptionsSource,
    this.schemaVersion = kAiroReleaseMatrixSchemaVersion,
  }) : expectedClients = List.unmodifiable(expectedClients);

  final String schemaVersion;
  final List<AiroFirebaseAndroidClientExpectation> expectedClients;
  final String googleServicesJson;
  final String firebaseOptionsSource;

  @override
  List<Object?> get props => [
    schemaVersion,
    expectedClients,
    googleServicesJson,
    firebaseOptionsSource,
  ];
}

class AiroFirebaseAndroidClientPreflight extends Equatable {
  AiroFirebaseAndroidClientPreflight({
    required Iterable<AiroFirebaseAndroidClientExpectation> expectedClients,
    required Iterable<AiroFirebaseAndroidClientConfig> googleServicesClients,
    required Iterable<AiroFirebaseAndroidOptionsConfig> firebaseOptions,
    required Iterable<AiroFirebaseAndroidClientFinding> findings,
    this.schemaVersion = kAiroReleaseMatrixSchemaVersion,
  }) : expectedClients = List.unmodifiable(expectedClients),
       googleServicesClients = List.unmodifiable(googleServicesClients),
       firebaseOptions = List.unmodifiable(firebaseOptions),
       findings = List.unmodifiable(findings);

  final String schemaVersion;
  final List<AiroFirebaseAndroidClientExpectation> expectedClients;
  final List<AiroFirebaseAndroidClientConfig> googleServicesClients;
  final List<AiroFirebaseAndroidOptionsConfig> firebaseOptions;
  final List<AiroFirebaseAndroidClientFinding> findings;

  bool get ready => !findings.any((finding) => finding.blocking);

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'ready': ready,
      'expectedPackages': expectedClients
          .map(
            (client) => {
              'packageName': client.packageName,
              'firebaseOptionsName': client.firebaseOptionsName,
            },
          )
          .toList(),
      'googleServicesClients': googleServicesClients
          .map((client) => client.toPublicMap())
          .toList(),
      'firebaseOptions': firebaseOptions
          .map((options) => options.toPublicMap())
          .toList(),
      'findings': findings.map((finding) => finding.toPublicMap()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Firebase Android Client Preflight')
      ..writeln()
      ..writeln('| Area | Status |')
      ..writeln('| --- | --- |')
      ..writeln('| Ready | `$ready` |')
      ..writeln('| Expected packages | `${expectedClients.length}` |')
      ..writeln(
        '| google-services clients | `${googleServicesClients.length}` |',
      )
      ..writeln('| Firebase option blocks | `${firebaseOptions.length}` |')
      ..writeln()
      ..writeln('## Expected Clients')
      ..writeln()
      ..writeln(
        '| Package | Firebase options | google-services | Options configured |',
      )
      ..writeln('| --- | --- | --- | --- |');

    for (final expected in expectedClients) {
      final googleClient = _googleServicesClientFor(expected.packageName);
      final options = _firebaseOptionsFor(expected.firebaseOptionsName);
      buffer.writeln(
        '| `${expected.packageName}` | `${expected.firebaseOptionsName}` | '
        '${googleClient == null ? 'missing' : 'present'} | '
        '${options?.configured ?? false} |',
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
      ..writeln('| Package | Code | Blocking | Message |')
      ..writeln('| --- | --- | --- | --- |');
    for (final finding in findings) {
      buffer.writeln(
        '| `${finding.packageName}` | `${finding.code.stableId}` | '
        '`${finding.blocking}` | ${finding.message} |',
      );
    }

    return buffer.toString();
  }

  AiroFirebaseAndroidClientConfig? _googleServicesClientFor(
    String packageName,
  ) {
    for (final client in googleServicesClients) {
      if (client.packageName == packageName) return client;
    }
    return null;
  }

  AiroFirebaseAndroidOptionsConfig? _firebaseOptionsFor(String optionsName) {
    for (final options in firebaseOptions) {
      if (options.optionsName == optionsName) return options;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    expectedClients,
    googleServicesClients,
    firebaseOptions,
    findings,
  ];
}

class AiroFirebaseAndroidClientPreflightRunner {
  const AiroFirebaseAndroidClientPreflightRunner();

  static const List<AiroFirebaseAndroidClientExpectation>
  v2MobileTabletExpectations = [
    AiroFirebaseAndroidClientExpectation(
      packageName: 'io.airo.app.iptv',
      firebaseOptionsName: 'androidIptv',
    ),
    AiroFirebaseAndroidClientExpectation(
      packageName: 'io.airo.app.streaming',
      firebaseOptionsName: 'androidStreaming',
    ),
  ];

  static List<AiroFirebaseAndroidClientExpectation>
  expectationsFromReleaseProfiles({
    required AiroReleaseMatrix matrix,
    required Iterable<String> profileIds,
  }) {
    return [
      for (final profileId in profileIds)
        _expectationForProfile(matrix.profileById(profileId)),
    ];
  }

  AiroFirebaseAndroidClientPreflight run(
    AiroFirebaseAndroidClientPreflightRequest request,
  ) {
    final expected = request.expectedClients
        .where((client) => client.packageName.trim().isNotEmpty)
        .toList(growable: false);
    final findings = <AiroFirebaseAndroidClientFinding>[];
    if (expected.isEmpty) {
      findings.add(
        const AiroFirebaseAndroidClientFinding(
          packageName: '*',
          code: AiroFirebaseAndroidClientFindingCode.missingExpectedPackage,
          message: 'At least one expected Android package is required.',
        ),
      );
    }

    final googleClients = parseGoogleServicesAndroidClients(
      request.googleServicesJson,
    );
    final firebaseOptions = parseFirebaseOptions(request.firebaseOptionsSource);

    for (final expectation in expected) {
      final googleClient = _firstGoogleClient(
        googleClients,
        expectation.packageName,
      );
      if (googleClient == null) {
        findings.add(
          AiroFirebaseAndroidClientFinding(
            packageName: expectation.packageName,
            code: AiroFirebaseAndroidClientFindingCode
                .missingGoogleServicesClient,
            message:
                'google-services.json does not include an Android client for '
                '${expectation.packageName}.',
          ),
        );
      }

      final options = _firstFirebaseOptions(
        firebaseOptions,
        expectation.firebaseOptionsName,
      );
      if (options == null) {
        findings.add(
          AiroFirebaseAndroidClientFinding(
            packageName: expectation.packageName,
            code: AiroFirebaseAndroidClientFindingCode
                .missingFirebaseOptionsBlock,
            message:
                'firebase_options.dart does not define '
                '${expectation.firebaseOptionsName} for '
                '${expectation.packageName}.',
          ),
        );
        continue;
      }
      if (!options.configured) {
        findings.add(
          AiroFirebaseAndroidClientFinding(
            packageName: expectation.packageName,
            code: AiroFirebaseAndroidClientFindingCode
                .placeholderFirebaseOptionsAppId,
            message:
                '${expectation.firebaseOptionsName}.appId is still a '
                'placeholder.',
          ),
        );
      }
      if (googleClient != null &&
          options.configured &&
          googleClient.mobileSdkAppId != options.appId) {
        findings.add(
          AiroFirebaseAndroidClientFinding(
            packageName: expectation.packageName,
            code: AiroFirebaseAndroidClientFindingCode
                .mismatchedFirebaseOptionsAppId,
            message:
                '${expectation.firebaseOptionsName}.appId does not match the '
                'redacted google-services Android client app id.',
          ),
        );
      }
    }

    return AiroFirebaseAndroidClientPreflight(
      expectedClients: expected,
      googleServicesClients: googleClients,
      firebaseOptions: firebaseOptions,
      findings: findings,
    );
  }

  static List<AiroFirebaseAndroidClientConfig>
  parseGoogleServicesAndroidClients(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('google-services.json must be an object.');
    }
    final clients = decoded['client'];
    if (clients is! List) {
      return const [];
    }
    final parsed = <AiroFirebaseAndroidClientConfig>[];
    for (final rawClient in clients) {
      if (rawClient is! Map) continue;
      final clientInfo = rawClient['client_info'];
      if (clientInfo is! Map) continue;
      final androidClientInfo = clientInfo['android_client_info'];
      if (androidClientInfo is! Map) continue;
      final packageName = androidClientInfo['package_name'];
      final mobileSdkAppId = clientInfo['mobilesdk_app_id'];
      if (packageName is String &&
          packageName.trim().isNotEmpty &&
          mobileSdkAppId is String &&
          mobileSdkAppId.trim().isNotEmpty) {
        parsed.add(
          AiroFirebaseAndroidClientConfig(
            packageName: packageName.trim(),
            mobileSdkAppId: mobileSdkAppId.trim(),
          ),
        );
      }
    }
    return List.unmodifiable(parsed);
  }

  static List<AiroFirebaseAndroidOptionsConfig> parseFirebaseOptions(
    String source,
  ) {
    if (source.trim().isEmpty) {
      return const [];
    }
    final regex = RegExp(
      r'static\s+const\s+FirebaseOptions\s+([A-Za-z0-9_]+)\s*='
      r'\s*FirebaseOptions\s*\((.*?)\);',
      dotAll: true,
      multiLine: true,
    );
    return List.unmodifiable([
      for (final match in regex.allMatches(source))
        if (_appIdFromFirebaseOptionsBlock(match.group(2)!) != null)
          AiroFirebaseAndroidOptionsConfig(
            optionsName: match.group(1)!,
            appId: _appIdFromFirebaseOptionsBlock(match.group(2)!)!,
          ),
    ]);
  }

  static String redactAppId(String appId) {
    final trimmed = appId.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.toUpperCase().contains('TODO') ||
        trimmed.toUpperCase().contains('YOUR_')) {
      return '<placeholder>';
    }
    if (trimmed.length <= 10) return '<redacted>';
    return '${trimmed.substring(0, 2)}...${trimmed.substring(trimmed.length - 6)}';
  }

  static AiroFirebaseAndroidClientConfig? _firstGoogleClient(
    List<AiroFirebaseAndroidClientConfig> clients,
    String packageName,
  ) {
    for (final client in clients) {
      if (client.packageName == packageName) return client;
    }
    return null;
  }

  static AiroFirebaseAndroidOptionsConfig? _firstFirebaseOptions(
    List<AiroFirebaseAndroidOptionsConfig> options,
    String optionsName,
  ) {
    for (final value in options) {
      if (value.optionsName == optionsName) return value;
    }
    return null;
  }

  static AiroFirebaseAndroidClientExpectation _expectationForProfile(
    AiroReleaseProfile profile,
  ) {
    return AiroFirebaseAndroidClientExpectation(
      packageName: profile.packageId,
      firebaseOptionsName: switch (profile.id) {
        'iptv-standalone' => 'androidIptv',
        'mobile-streaming' => 'androidStreaming',
        'tv' => 'androidTv',
        _ => 'android',
      },
    );
  }

  static String? _appIdFromFirebaseOptionsBlock(String block) {
    final appId = RegExp(
      r'''appId\s*:\s*['"]([^'"]+)['"]''',
      multiLine: true,
    ).firstMatch(block);
    return appId?.group(1)?.trim();
  }
}
