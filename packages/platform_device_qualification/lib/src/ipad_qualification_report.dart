const List<IpadQualificationPhaseDefinition> kDefaultIpadQualificationPhases = [
  IpadQualificationPhaseDefinition(
    id: 'phase1_splash',
    title: 'Phase 1: Splash Screen',
  ),
  IpadQualificationPhaseDefinition(
    id: 'phase1_home',
    title: 'Phase 1: Home Screen',
  ),
  IpadQualificationPhaseDefinition(
    id: 'phase1_channel_grid',
    title: 'Phase 1: Channel Grid',
  ),
  IpadQualificationPhaseDefinition(
    id: 'phase1_video_player',
    title: 'Phase 1: Video Player',
  ),
  IpadQualificationPhaseDefinition(
    id: 'phase1_search',
    title: 'Phase 1: Search Tab',
  ),
  IpadQualificationPhaseDefinition(
    id: 'phase1_settings',
    title: 'Phase 1: Settings Screen',
  ),
  IpadQualificationPhaseDefinition(
    id: 'phase1_playlist_management',
    title: 'Phase 1: Playlist Management',
  ),
  IpadQualificationPhaseDefinition(
    id: 'phase2_responsive_layouts',
    title: 'Phase 2: Responsive Layouts',
  ),
  IpadQualificationPhaseDefinition(
    id: 'phase3_dpad_focus',
    title: 'Phase 3: D-pad Remote Navigation and Focus States',
  ),
  IpadQualificationPhaseDefinition(
    id: 'phase4_streaming_stress',
    title: 'Phase 4: Streaming Stress Checks',
  ),
  IpadQualificationPhaseDefinition(
    id: 'phase5_network_profiles',
    title: 'Phase 5: Network Profiles',
  ),
];

enum IpadQualificationPhaseStatus {
  passed('passed'),
  failed('failed'),
  waived('waived'),
  missing('missing');

  const IpadQualificationPhaseStatus(this.stableId);

  final String stableId;

  bool get complete => this == passed || this == waived;

  static IpadQualificationPhaseStatus parse(String value) {
    final normalized = value.trim().toLowerCase();
    for (final status in values) {
      if (status.stableId == normalized) {
        return status;
      }
    }
    if (normalized == 'pass') {
      return passed;
    }
    if (normalized == 'fail') {
      return failed;
    }
    if (normalized == 'waive') {
      return waived;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported phase status.');
  }
}

class IpadQualificationPhaseDefinition {
  const IpadQualificationPhaseDefinition({
    required this.id,
    required this.title,
  });

  final String id;
  final String title;
}

class IpadQualificationPhaseResult {
  const IpadQualificationPhaseResult({
    required this.id,
    required this.title,
    required this.status,
    this.defectCount = 0,
    this.note = '',
  });

  final String id;
  final String title;
  final IpadQualificationPhaseStatus status;
  final int defectCount;
  final String note;

  bool get complete {
    if (status == IpadQualificationPhaseStatus.waived) {
      return true;
    }
    return status == IpadQualificationPhaseStatus.passed && defectCount == 0;
  }

  Map<String, Object?> toPublicMap() {
    return {
      'id': id,
      'title': title,
      'status': status.stableId,
      'defectCount': defectCount,
      'note': note,
      'complete': complete,
    };
  }
}

class IpadQualificationFinding {
  const IpadQualificationFinding({
    required this.code,
    required this.message,
    this.blocking = true,
  });

  final String code;
  final String message;
  final bool blocking;

  Map<String, Object?> toPublicMap() {
    return {'code': code, 'message': message, 'blocking': blocking};
  }
}

class IpadQualificationReport {
  IpadQualificationReport({
    required this.reportId,
    required this.campaignId,
    required this.deviceName,
    required this.appProfile,
    required this.playlistProfile,
    required Iterable<IpadQualificationPhaseResult> phases,
    required Iterable<IpadQualificationFinding> findings,
    this.schemaVersion = '1.0.0',
  }) : phases = List.unmodifiable(phases),
       findings = List.unmodifiable(findings);

  final String schemaVersion;
  final String reportId;
  final String campaignId;
  final String deviceName;
  final String appProfile;
  final String playlistProfile;
  final List<IpadQualificationPhaseResult> phases;
  final List<IpadQualificationFinding> findings;

  int get passedCount => phases
      .where((phase) => phase.status == IpadQualificationPhaseStatus.passed)
      .length;
  int get failedCount => phases
      .where((phase) => phase.status == IpadQualificationPhaseStatus.failed)
      .length;
  int get waivedCount => phases
      .where((phase) => phase.status == IpadQualificationPhaseStatus.waived)
      .length;
  int get missingCount => phases
      .where((phase) => phase.status == IpadQualificationPhaseStatus.missing)
      .length;
  int get defectCount =>
      phases.fold<int>(0, (total, phase) => total + phase.defectCount);

  bool get completeForIssueEvidence =>
      phases.isNotEmpty &&
      phases.every((phase) => phase.complete) &&
      !findings.any((finding) => finding.blocking);

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'reportId': reportId,
      'campaignId': campaignId,
      'deviceName': deviceName,
      'appProfile': appProfile,
      'playlistProfile': playlistProfile,
      'summary': {
        'completeForIssueEvidence': completeForIssueEvidence,
        'passed': passedCount,
        'failed': failedCount,
        'waived': waivedCount,
        'missing': missingCount,
        'defects': defectCount,
      },
      'phases': phases.map((phase) => phase.toPublicMap()).toList(),
      'findings': findings.map((finding) => finding.toPublicMap()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# iPad Air Qualification Report')
      ..writeln()
      ..writeln('| Area | Value |')
      ..writeln('| --- | --- |')
      ..writeln('| Report | `$reportId` |')
      ..writeln('| Campaign | `$campaignId` |')
      ..writeln('| Device | $deviceName |')
      ..writeln('| App profile | `$appProfile` |')
      ..writeln('| Playlist profile | `$playlistProfile` |')
      ..writeln('| Complete for issue evidence | `$completeForIssueEvidence` |')
      ..writeln('| Passed | `$passedCount` |')
      ..writeln('| Failed | `$failedCount` |')
      ..writeln('| Waived | `$waivedCount` |')
      ..writeln('| Missing | `$missingCount` |')
      ..writeln('| Defects | `$defectCount` |')
      ..writeln()
      ..writeln('## Phases')
      ..writeln()
      ..writeln('| Phase | Status | Defects | Note |')
      ..writeln('| --- | --- | --- | --- |');

    for (final phase in phases) {
      buffer.writeln(
        '| ${phase.title} | `${phase.status.stableId}` | '
        '`${phase.defectCount}` | ${phase.note} |',
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
      ..writeln('| Code | Blocking | Message |')
      ..writeln('| --- | --- | --- |');
    for (final finding in findings) {
      buffer.writeln(
        '| `${finding.code}` | `${finding.blocking}` | ${finding.message} |',
      );
    }

    return buffer.toString();
  }
}

class IpadQualificationReportBuilder {
  const IpadQualificationReportBuilder({
    this.phaseDefinitions = kDefaultIpadQualificationPhases,
  });

  final List<IpadQualificationPhaseDefinition> phaseDefinitions;

  IpadQualificationReport build({
    required String reportId,
    required String campaignId,
    required String deviceName,
    required String appProfile,
    required String playlistProfile,
    required Map<String, IpadQualificationPhaseStatus> phaseStatuses,
    Map<String, int> defectCounts = const {},
    Map<String, String> notes = const {},
  }) {
    final phases = <IpadQualificationPhaseResult>[];
    final findings = <IpadQualificationFinding>[];

    for (final definition in phaseDefinitions) {
      final status =
          phaseStatuses[definition.id] ?? IpadQualificationPhaseStatus.missing;
      final defectCount = defectCounts[definition.id] ?? 0;
      final note = notes[definition.id] ?? '';
      phases.add(
        IpadQualificationPhaseResult(
          id: definition.id,
          title: definition.title,
          status: status,
          defectCount: defectCount,
          note: note,
        ),
      );

      if (status == IpadQualificationPhaseStatus.missing) {
        findings.add(
          IpadQualificationFinding(
            code: 'missing_phase_evidence',
            message: '${definition.title} has no recorded iPad Air result.',
          ),
        );
      } else if (status == IpadQualificationPhaseStatus.failed) {
        findings.add(
          IpadQualificationFinding(
            code: 'failed_phase',
            message: '${definition.title} failed and needs defect triage.',
          ),
        );
      }
      if (defectCount > 0 && status != IpadQualificationPhaseStatus.waived) {
        findings.add(
          IpadQualificationFinding(
            code: 'unwaived_defects',
            message:
                '${definition.title} has $defectCount defect(s) without a waiver.',
          ),
        );
      }
    }

    return IpadQualificationReport(
      reportId: reportId,
      campaignId: campaignId,
      deviceName: deviceName,
      appProfile: appProfile,
      playlistProfile: playlistProfile,
      phases: phases,
      findings: findings,
    );
  }
}
