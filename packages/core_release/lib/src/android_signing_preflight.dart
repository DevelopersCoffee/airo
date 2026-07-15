import 'package:equatable/equatable.dart';

import 'release_matrix.dart';

enum AiroAndroidSigningInput {
  keystoreBase64('ANDROID_RELEASE_KEYSTORE_BASE64'),
  keystorePassword('KEYSTORE_PASSWORD'),
  keyAlias('KEY_ALIAS'),
  keyPassword('KEY_PASSWORD');

  const AiroAndroidSigningInput(this.environmentName);

  final String environmentName;
}

enum AiroAndroidSigningFindingCode {
  productionSigningDisabled('production_signing_disabled'),
  missingSigningInput('missing_signing_input'),
  invalidKeystoreBase64('invalid_keystore_base64');

  const AiroAndroidSigningFindingCode(this.stableId);

  final String stableId;
}

class AiroAndroidSigningInputStatus extends Equatable {
  const AiroAndroidSigningInputStatus({
    required this.input,
    required this.present,
    this.source,
  });

  final AiroAndroidSigningInput input;
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

class AiroAndroidSigningFinding extends Equatable {
  const AiroAndroidSigningFinding({
    required this.code,
    required this.message,
    this.input,
    this.blocking = true,
  });

  final AiroAndroidSigningFindingCode code;
  final String message;
  final AiroAndroidSigningInput? input;
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

class AiroAndroidSigningPreflightRequest extends Equatable {
  const AiroAndroidSigningPreflightRequest({
    required this.environment,
    this.productionSigning = true,
    this.keystoreFileExists = false,
  });

  final Map<String, String> environment;
  final bool productionSigning;
  final bool keystoreFileExists;

  @override
  List<Object?> get props => [
    environment,
    productionSigning,
    keystoreFileExists,
  ];
}

class AiroAndroidSigningPreflight extends Equatable {
  AiroAndroidSigningPreflight({
    required this.productionSigning,
    required Iterable<AiroAndroidSigningInputStatus> inputs,
    required Iterable<AiroAndroidSigningFinding> findings,
    this.schemaVersion = kAiroReleaseMatrixSchemaVersion,
  }) : inputs = List.unmodifiable(inputs),
       findings = List.unmodifiable(findings);

  final String schemaVersion;
  final bool productionSigning;
  final List<AiroAndroidSigningInputStatus> inputs;
  final List<AiroAndroidSigningFinding> findings;

  bool get ready => !findings.any((finding) => finding.blocking);

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'ready': ready,
      'productionSigning': productionSigning,
      'inputs': inputs.map((input) => input.toPublicMap()).toList(),
      'findings': findings.map((finding) => finding.toPublicMap()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Android Signing Preflight')
      ..writeln()
      ..writeln('| Area | Status |')
      ..writeln('| --- | --- |')
      ..writeln('| Ready | `$ready` |')
      ..writeln('| Production signing | `$productionSigning` |')
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
    productionSigning,
    inputs,
    findings,
  ];
}

class AiroAndroidSigningPreflightRunner {
  const AiroAndroidSigningPreflightRunner();

  static const List<AiroAndroidSigningInput> requiredInputs = [
    AiroAndroidSigningInput.keystoreBase64,
    AiroAndroidSigningInput.keystorePassword,
    AiroAndroidSigningInput.keyAlias,
    AiroAndroidSigningInput.keyPassword,
  ];

  AiroAndroidSigningPreflight run(AiroAndroidSigningPreflightRequest request) {
    final findings = <AiroAndroidSigningFinding>[];
    final inputs = <AiroAndroidSigningInputStatus>[];

    if (!request.productionSigning) {
      findings.add(
        const AiroAndroidSigningFinding(
          code: AiroAndroidSigningFindingCode.productionSigningDisabled,
          blocking: false,
          message:
              'Production signing is disabled; workflows will use validation '
              'signing and must not be treated as store-ready.',
        ),
      );
    }

    for (final input in requiredInputs) {
      final source = _sourceFor(request, input);
      final present = source != null;
      inputs.add(
        AiroAndroidSigningInputStatus(
          input: input,
          present: present,
          source: source,
        ),
      );
      if (request.productionSigning && !present) {
        findings.add(
          AiroAndroidSigningFinding(
            input: input,
            code: AiroAndroidSigningFindingCode.missingSigningInput,
            message:
                'Set ${input.environmentName} before running Android release '
                'workflows with production_signing=true.',
          ),
        );
      }
    }

    final keystoreValue = request
        .environment[AiroAndroidSigningInput.keystoreBase64.environmentName]
        ?.trim();
    if (request.productionSigning &&
        keystoreValue != null &&
        keystoreValue.isNotEmpty &&
        !_looksBase64(keystoreValue)) {
      findings.add(
        const AiroAndroidSigningFinding(
          input: AiroAndroidSigningInput.keystoreBase64,
          code: AiroAndroidSigningFindingCode.invalidKeystoreBase64,
          message:
              'ANDROID_RELEASE_KEYSTORE_BASE64 is present but is not shaped '
              'like base64-encoded keystore data.',
        ),
      );
    }

    return AiroAndroidSigningPreflight(
      productionSigning: request.productionSigning,
      inputs: inputs,
      findings: findings,
    );
  }

  String? _sourceFor(
    AiroAndroidSigningPreflightRequest request,
    AiroAndroidSigningInput input,
  ) {
    final envValue = request.environment[input.environmentName]?.trim();
    if (envValue != null && envValue.isNotEmpty) {
      return 'env:${input.environmentName}';
    }
    if (input == AiroAndroidSigningInput.keystoreBase64 &&
        request.keystoreFileExists) {
      return 'file:app/android/release.keystore';
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
