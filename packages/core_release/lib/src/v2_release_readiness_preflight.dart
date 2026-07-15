import 'package:equatable/equatable.dart';

import 'release_matrix.dart';

enum AiroV2ReleaseGateStatus {
  unknown('unknown'),
  blocked('blocked'),
  ready('ready'),
  waived('waived'),
  deferred('deferred'),
  notInScope('not_in_scope');

  const AiroV2ReleaseGateStatus(this.stableId);

  final String stableId;

  bool get satisfiesPublicRelease {
    return this == ready || this == waived || this == notInScope;
  }

  static AiroV2ReleaseGateStatus parse(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('-', '_');
    for (final status in values) {
      if (status.stableId == normalized) {
        return status;
      }
    }
    throw ArgumentError.value(
      value,
      'value',
      'Expected unknown, blocked, ready, waived, deferred, or not_in_scope.',
    );
  }
}

enum AiroV2ReleaseReadinessFindingCode {
  missingRequiredGate('missing_required_gate'),
  blockedRequiredGate('blocked_required_gate'),
  deferredRequiredGate('deferred_required_gate'),
  unknownRequiredGate('unknown_required_gate');

  const AiroV2ReleaseReadinessFindingCode(this.stableId);

  final String stableId;
}

class AiroV2ReleaseReadinessGate extends Equatable {
  const AiroV2ReleaseReadinessGate({
    required this.id,
    required this.issueNumber,
    required this.title,
    required this.owner,
    required this.status,
    this.requiredForPublicRelease = true,
    this.note = '',
  });

  final String id;
  final int issueNumber;
  final String title;
  final String owner;
  final AiroV2ReleaseGateStatus status;
  final bool requiredForPublicRelease;
  final String note;

  bool get readyForPublicRelease {
    if (!requiredForPublicRelease) {
      return status != AiroV2ReleaseGateStatus.blocked &&
          status != AiroV2ReleaseGateStatus.unknown;
    }
    return status.satisfiesPublicRelease;
  }

  AiroV2ReleaseReadinessGate copyWith({
    AiroV2ReleaseGateStatus? status,
    String? note,
  }) {
    return AiroV2ReleaseReadinessGate(
      id: id,
      issueNumber: issueNumber,
      title: title,
      owner: owner,
      status: status ?? this.status,
      requiredForPublicRelease: requiredForPublicRelease,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'id': id,
      'issueNumber': issueNumber,
      'title': title,
      'owner': owner,
      'status': status.stableId,
      'requiredForPublicRelease': requiredForPublicRelease,
      'readyForPublicRelease': readyForPublicRelease,
      if (note.isNotEmpty) 'note': note,
    };
  }

  @override
  List<Object?> get props => [
    id,
    issueNumber,
    title,
    owner,
    status,
    requiredForPublicRelease,
    note,
  ];
}

class AiroV2ReleaseReadinessFinding extends Equatable {
  const AiroV2ReleaseReadinessFinding({
    required this.code,
    required this.gateId,
    required this.issueNumber,
    required this.message,
    this.blocking = true,
  });

  final AiroV2ReleaseReadinessFindingCode code;
  final String gateId;
  final int issueNumber;
  final String message;
  final bool blocking;

  Map<String, Object?> toPublicMap() {
    return {
      'code': code.stableId,
      'gateId': gateId,
      'issueNumber': issueNumber,
      'message': message,
      'blocking': blocking,
    };
  }

  @override
  List<Object?> get props => [code, gateId, issueNumber, message, blocking];
}

class AiroV2ReleaseReadinessPreflight extends Equatable {
  AiroV2ReleaseReadinessPreflight({
    required Iterable<AiroV2ReleaseReadinessGate> gates,
    required Iterable<AiroV2ReleaseReadinessFinding> findings,
    this.schemaVersion = kAiroReleaseMatrixSchemaVersion,
  }) : gates = List.unmodifiable(gates),
       findings = List.unmodifiable(findings);

  final String schemaVersion;
  final List<AiroV2ReleaseReadinessGate> gates;
  final List<AiroV2ReleaseReadinessFinding> findings;

  bool get publicReady => !findings.any((finding) => finding.blocking);

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'publicReady': publicReady,
      'gates': gates.map((gate) => gate.toPublicMap()).toList(),
      'findings': findings.map((finding) => finding.toPublicMap()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# V2 Release Readiness Preflight')
      ..writeln()
      ..writeln('| Area | Status |')
      ..writeln('| --- | --- |')
      ..writeln('| Public ready | `$publicReady` |')
      ..writeln('| Gates | `${gates.length}` |')
      ..writeln('| Findings | `${findings.length}` |')
      ..writeln()
      ..writeln('## Gates')
      ..writeln()
      ..writeln('| Gate | Issue | Required | Status | Owner | Note |')
      ..writeln('| --- | --- | --- | --- | --- | --- |');

    for (final gate in gates) {
      buffer.writeln(
        '| `${gate.id}` | #${gate.issueNumber} | '
        '`${gate.requiredForPublicRelease}` | `${gate.status.stableId}` | '
        '${_md(gate.owner)} | ${_md(gate.note)} |',
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
      ..writeln('| Code | Gate | Issue | Blocking | Message |')
      ..writeln('| --- | --- | --- | --- | --- |');
    for (final finding in findings) {
      buffer.writeln(
        '| `${finding.code.stableId}` | `${finding.gateId}` | '
        '#${finding.issueNumber} | `${finding.blocking}` | '
        '${_md(finding.message)} |',
      );
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props => [schemaVersion, gates, findings];
}

class AiroV2ReleaseReadinessPreflightRunner {
  const AiroV2ReleaseReadinessPreflightRunner();

  static const List<AiroV2ReleaseReadinessGate> defaultGates = [
    AiroV2ReleaseReadinessGate(
      id: 'firebase_mobile_clients',
      issueNumber: 756,
      title: 'Firebase Android clients for mobile/tablet profiles',
      owner: 'Release and CI/CD',
      status: AiroV2ReleaseGateStatus.unknown,
      note: 'Requires io.airo.app.iptv and io.airo.app.streaming clients.',
    ),
    AiroV2ReleaseReadinessGate(
      id: 'android_signing',
      issueNumber: 576,
      title: 'Android release signing secrets',
      owner: 'Release and CI/CD',
      status: AiroV2ReleaseGateStatus.unknown,
    ),
    AiroV2ReleaseReadinessGate(
      id: 'store_credentials',
      issueNumber: 585,
      title: 'Play/App Store automation credentials and track decisions',
      owner: 'Release and CI/CD',
      status: AiroV2ReleaseGateStatus.unknown,
    ),
    AiroV2ReleaseReadinessGate(
      id: 'firebase_distribution',
      issueNumber: 682,
      title: 'Firebase App Distribution apps and tester groups',
      owner: 'Release QA',
      status: AiroV2ReleaseGateStatus.unknown,
    ),
    AiroV2ReleaseReadinessGate(
      id: 'data_safety',
      issueNumber: 583,
      title: 'Play Data Safety and App Privacy forms',
      owner: 'Store compliance',
      status: AiroV2ReleaseGateStatus.unknown,
    ),
    AiroV2ReleaseReadinessGate(
      id: 'content_rating',
      issueNumber: 584,
      title: 'IARC and age rating forms',
      owner: 'Store compliance',
      status: AiroV2ReleaseGateStatus.unknown,
    ),
    AiroV2ReleaseReadinessGate(
      id: 'release_qualification',
      issueNumber: 683,
      title: 'Release qualification evidence',
      owner: 'QA Automation',
      status: AiroV2ReleaseGateStatus.unknown,
    ),
    AiroV2ReleaseReadinessGate(
      id: 'tv_ui_dpad_qualification',
      issueNumber: 589,
      title: 'Airo TV UI and D-pad release audit evidence',
      owner: 'Mobile UI and QA Automation',
      status: AiroV2ReleaseGateStatus.unknown,
      note: 'Requires physical Android TV or Fire TV D-pad traversal evidence.',
    ),
    AiroV2ReleaseReadinessGate(
      id: 'cast_active_receiver_switching',
      issueNumber: 590,
      title: 'Cast active-receiver channel switching evidence',
      owner: 'Media and QA Automation',
      status: AiroV2ReleaseGateStatus.unknown,
      note:
          'Requires physical Android sender to BRAVIA or Chromecast-class '
          'receiver validation.',
    ),
    AiroV2ReleaseReadinessGate(
      id: 'cast_v1_device_qa',
      issueNumber: 459,
      title: 'IPTV Cast V1 real-device QA matrix evidence',
      owner: 'Media and QA Automation',
      status: AiroV2ReleaseGateStatus.unknown,
      note: 'Covers the Cast V1 QA matrix and parent Cast epic closure path.',
    ),
    AiroV2ReleaseReadinessGate(
      id: 'ipad_air_qualification',
      issueNumber: 716,
      title: 'iPad Air UI/UX qualification evidence',
      owner: 'QA Automation',
      status: AiroV2ReleaseGateStatus.unknown,
      note: 'Requires physical iPad Air qualification report or waiver.',
    ),
    AiroV2ReleaseReadinessGate(
      id: 'memory_playback_soak',
      issueNumber: 779,
      title: 'Airo TV memory playback soak evidence',
      owner: 'Performance and QA Automation',
      status: AiroV2ReleaseGateStatus.unknown,
      note:
          'Requires constrained TV memory timeline and 30-minute playback '
          'soak drift evidence.',
    ),
    AiroV2ReleaseReadinessGate(
      id: 'legal_provenance',
      issueNumber: 687,
      title: 'Legal and provenance decisions',
      owner: 'Security and Docs',
      status: AiroV2ReleaseGateStatus.unknown,
    ),
    AiroV2ReleaseReadinessGate(
      id: 'repository_health',
      issueNumber: 689,
      title: 'Repository governance decisions',
      owner: 'DevEx and Docs',
      status: AiroV2ReleaseGateStatus.unknown,
    ),
    AiroV2ReleaseReadinessGate(
      id: 'kgp_scope_decision',
      issueNumber: 568,
      title: 'Kotlin Gradle Plugin scope decision',
      owner: 'Android Release',
      status: AiroV2ReleaseGateStatus.unknown,
    ),
    AiroV2ReleaseReadinessGate(
      id: 'macos_signing',
      issueNumber: 803,
      title: 'macOS signing and notarization',
      owner: 'Release and Security',
      status: AiroV2ReleaseGateStatus.unknown,
      requiredForPublicRelease: false,
      note:
          'Required only when macOS public direct-download release is in scope.',
    ),
  ];

  AiroV2ReleaseReadinessPreflight run({
    Iterable<AiroV2ReleaseReadinessGate> gates = defaultGates,
    Map<String, AiroV2ReleaseGateStatus> overrides = const {},
    Map<String, String> notes = const {},
  }) {
    final byId = {for (final gate in gates) gate.id: gate};
    final findings = <AiroV2ReleaseReadinessFinding>[];

    for (final id in overrides.keys) {
      if (!byId.containsKey(id)) {
        findings.add(
          AiroV2ReleaseReadinessFinding(
            code: AiroV2ReleaseReadinessFindingCode.missingRequiredGate,
            gateId: id,
            issueNumber: 0,
            message: 'Unknown release readiness gate override: $id.',
          ),
        );
      }
    }

    final evaluated = [
      for (final gate in gates)
        gate.copyWith(
          status: overrides[gate.id],
          note: notes[gate.id] ?? gate.note,
        ),
    ];

    for (final gate in evaluated) {
      if (gate.readyForPublicRelease) {
        continue;
      }
      findings.add(_findingForGate(gate));
    }

    return AiroV2ReleaseReadinessPreflight(
      gates: evaluated,
      findings: findings,
    );
  }

  AiroV2ReleaseReadinessFinding _findingForGate(
    AiroV2ReleaseReadinessGate gate,
  ) {
    final code = switch (gate.status) {
      AiroV2ReleaseGateStatus.unknown =>
        AiroV2ReleaseReadinessFindingCode.unknownRequiredGate,
      AiroV2ReleaseGateStatus.deferred =>
        AiroV2ReleaseReadinessFindingCode.deferredRequiredGate,
      _ => AiroV2ReleaseReadinessFindingCode.blockedRequiredGate,
    };
    return AiroV2ReleaseReadinessFinding(
      code: code,
      gateId: gate.id,
      issueNumber: gate.issueNumber,
      message:
          '${gate.title} is ${gate.status.stableId}; public v2 release is not ready.',
      blocking: gate.requiredForPublicRelease,
    );
  }
}

String _md(String value) {
  return value.replaceAll('|', r'\|').replaceAll('\n', ' ');
}
