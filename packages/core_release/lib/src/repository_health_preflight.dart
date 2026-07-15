import 'package:equatable/equatable.dart';

import 'release_matrix.dart';

enum AiroRepositoryDecision {
  unknown('unknown'),
  enabled('enabled'),
  present('present'),
  notRequired('not_required'),
  intentionallyAbsent('intentionally_absent');

  const AiroRepositoryDecision(this.stableId);

  final String stableId;

  static AiroRepositoryDecision parse(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('-', '_');
    for (final decision in values) {
      if (decision.stableId == normalized) {
        return decision;
      }
    }
    throw ArgumentError.value(
      value,
      'value',
      'Expected unknown, enabled, present, not_required, or intentionally_absent.',
    );
  }
}

enum AiroRepositoryHealthFindingCode {
  missingRequiredFile('missing_required_file'),
  missingReadmeLink('missing_readme_link'),
  missingIssueTemplate('missing_issue_template'),
  missingLabel('missing_label'),
  labelSourceUnavailable('label_source_unavailable'),
  discussionsDecisionMissing('discussions_decision_missing'),
  codeownersDecisionMissing('codeowners_decision_missing'),
  codeownersRequiredButMissing('codeowners_required_but_missing'),
  fundingDecisionMissing('funding_decision_missing'),
  fundingRequiredButMissing('funding_required_but_missing');

  const AiroRepositoryHealthFindingCode(this.stableId);

  final String stableId;
}

class AiroRepositoryFileStatus extends Equatable {
  const AiroRepositoryFileStatus({required this.path, required this.present});

  final String path;
  final bool present;

  Map<String, Object?> toPublicMap() {
    return {'path': path, 'present': present};
  }

  @override
  List<Object?> get props => [path, present];
}

class AiroRepositoryHealthFinding extends Equatable {
  const AiroRepositoryHealthFinding({
    required this.code,
    required this.message,
    this.path,
    this.label,
    this.blocking = true,
  });

  final AiroRepositoryHealthFindingCode code;
  final String message;
  final String? path;
  final String? label;
  final bool blocking;

  Map<String, Object?> toPublicMap() {
    return {
      'code': code.stableId,
      if (path != null) 'path': path,
      if (label != null) 'label': label,
      'message': message,
      'blocking': blocking,
    };
  }

  @override
  List<Object?> get props => [code, message, path, label, blocking];
}

class AiroRepositoryHealthPreflightRequest extends Equatable {
  AiroRepositoryHealthPreflightRequest({
    required Iterable<AiroRepositoryFileStatus> requiredFiles,
    required Iterable<AiroRepositoryFileStatus> issueTemplates,
    required Iterable<String> readmeTextChecks,
    required Iterable<String> labels,
    required this.labelsAvailable,
    required this.codeownersPresent,
    required this.fundingPresent,
    this.discussionsDecision = AiroRepositoryDecision.unknown,
    this.codeownersDecision = AiroRepositoryDecision.unknown,
    this.fundingDecision = AiroRepositoryDecision.unknown,
  }) : requiredFiles = List.unmodifiable(requiredFiles),
       issueTemplates = List.unmodifiable(issueTemplates),
       readmeTextChecks = List.unmodifiable(readmeTextChecks),
       labels = Set.unmodifiable(labels.map((label) => label.toLowerCase()));

  final List<AiroRepositoryFileStatus> requiredFiles;
  final List<AiroRepositoryFileStatus> issueTemplates;
  final List<String> readmeTextChecks;
  final Set<String> labels;
  final bool labelsAvailable;
  final bool codeownersPresent;
  final bool fundingPresent;
  final AiroRepositoryDecision discussionsDecision;
  final AiroRepositoryDecision codeownersDecision;
  final AiroRepositoryDecision fundingDecision;

  @override
  List<Object?> get props => [
    requiredFiles,
    issueTemplates,
    readmeTextChecks,
    labels,
    labelsAvailable,
    codeownersPresent,
    fundingPresent,
    discussionsDecision,
    codeownersDecision,
    fundingDecision,
  ];
}

class AiroRepositoryHealthPreflight extends Equatable {
  AiroRepositoryHealthPreflight({
    required Iterable<AiroRepositoryFileStatus> requiredFiles,
    required Iterable<AiroRepositoryFileStatus> issueTemplates,
    required Iterable<String> requiredLabels,
    required Iterable<String> presentLabels,
    required this.labelsAvailable,
    required this.codeownersPresent,
    required this.fundingPresent,
    required this.discussionsDecision,
    required this.codeownersDecision,
    required this.fundingDecision,
    required Iterable<AiroRepositoryHealthFinding> findings,
    this.schemaVersion = kAiroReleaseMatrixSchemaVersion,
  }) : requiredFiles = List.unmodifiable(requiredFiles),
       issueTemplates = List.unmodifiable(issueTemplates),
       requiredLabels = List.unmodifiable(requiredLabels),
       presentLabels = List.unmodifiable(presentLabels),
       findings = List.unmodifiable(findings);

  final String schemaVersion;
  final List<AiroRepositoryFileStatus> requiredFiles;
  final List<AiroRepositoryFileStatus> issueTemplates;
  final List<String> requiredLabels;
  final List<String> presentLabels;
  final bool labelsAvailable;
  final bool codeownersPresent;
  final bool fundingPresent;
  final AiroRepositoryDecision discussionsDecision;
  final AiroRepositoryDecision codeownersDecision;
  final AiroRepositoryDecision fundingDecision;
  final List<AiroRepositoryHealthFinding> findings;

  bool get ready => !findings.any((finding) => finding.blocking);

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'ready': ready,
      'requiredFiles': requiredFiles.map((file) => file.toPublicMap()).toList(),
      'issueTemplates': issueTemplates
          .map((file) => file.toPublicMap())
          .toList(),
      'requiredLabels': requiredLabels,
      'presentLabels': presentLabels,
      'labelsAvailable': labelsAvailable,
      'codeownersPresent': codeownersPresent,
      'fundingPresent': fundingPresent,
      'discussionsDecision': discussionsDecision.stableId,
      'codeownersDecision': codeownersDecision.stableId,
      'fundingDecision': fundingDecision.stableId,
      'findings': findings.map((finding) => finding.toPublicMap()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Repository Health Preflight')
      ..writeln()
      ..writeln('| Area | Status |')
      ..writeln('| --- | --- |')
      ..writeln('| Ready | `$ready` |')
      ..writeln('| Labels available | `$labelsAvailable` |')
      ..writeln('| CODEOWNERS present | `$codeownersPresent` |')
      ..writeln('| Funding metadata present | `$fundingPresent` |')
      ..writeln('| Discussions decision | `${discussionsDecision.stableId}` |')
      ..writeln('| CODEOWNERS decision | `${codeownersDecision.stableId}` |')
      ..writeln('| Funding decision | `${fundingDecision.stableId}` |')
      ..writeln()
      ..writeln('## Required Files')
      ..writeln()
      ..writeln('| File | Present |')
      ..writeln('| --- | --- |');

    for (final file in requiredFiles) {
      buffer.writeln('| `${file.path}` | `${file.present}` |');
    }

    buffer
      ..writeln()
      ..writeln('## Issue Templates')
      ..writeln()
      ..writeln('| File | Present |')
      ..writeln('| --- | --- |');
    for (final file in issueTemplates) {
      buffer.writeln('| `${file.path}` | `${file.present}` |');
    }

    buffer
      ..writeln()
      ..writeln('## Labels')
      ..writeln()
      ..writeln('| Required Label | Present |')
      ..writeln('| --- | --- |');
    for (final label in requiredLabels) {
      buffer.writeln(
        '| `$label` | `${presentLabels.contains(label.toLowerCase())}` |',
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
      ..writeln('| Code | Path | Label | Blocking | Message |')
      ..writeln('| --- | --- | --- | --- | --- |');
    for (final finding in findings) {
      buffer.writeln(
        '| `${finding.code.stableId}` | `${finding.path ?? ''}` | '
        '`${finding.label ?? ''}` | `${finding.blocking}` | '
        '${finding.message} |',
      );
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    requiredFiles,
    issueTemplates,
    requiredLabels,
    presentLabels,
    labelsAvailable,
    codeownersPresent,
    fundingPresent,
    discussionsDecision,
    codeownersDecision,
    fundingDecision,
    findings,
  ];
}

class AiroRepositoryHealthPreflightRunner {
  const AiroRepositoryHealthPreflightRunner();

  static const List<String> requiredReadmeText = [
    '.github/workflows/v2-release-orchestrator.yml',
    'docs/release/V2_RELEASE_ORCHESTRATOR.md',
    'docs/release/V2_PUBLISHING_HUMAN_SETUP.md',
    'docs/release/RELEASE_CHECKLIST.md',
    'SECURITY.md',
    'CONTRIBUTING.md',
    'CODE_OF_CONDUCT.md',
  ];

  static const List<String> requiredLabels = [
    'release/v2.0.0.1',
    'store-readiness',
    'platform-android',
    'airo-tv',
    'fire-tv',
    'documentation',
    'agent/security',
    'agent/ci-cd',
    'agent/qa-testing',
    'blocked',
  ];

  AiroRepositoryHealthPreflight run(
    AiroRepositoryHealthPreflightRequest request,
  ) {
    final findings = <AiroRepositoryHealthFinding>[];

    for (final file in request.requiredFiles) {
      if (!file.present) {
        findings.add(
          AiroRepositoryHealthFinding(
            code: AiroRepositoryHealthFindingCode.missingRequiredFile,
            path: file.path,
            message:
                'Required public repository file is missing: ${file.path}.',
          ),
        );
      }
    }

    for (final template in request.issueTemplates) {
      if (!template.present) {
        findings.add(
          AiroRepositoryHealthFinding(
            code: AiroRepositoryHealthFindingCode.missingIssueTemplate,
            path: template.path,
            message:
                'Required public issue template is missing: ${template.path}.',
          ),
        );
      }
    }

    for (final check in request.readmeTextChecks) {
      if (!check.startsWith('present:')) {
        findings.add(
          AiroRepositoryHealthFinding(
            code: AiroRepositoryHealthFindingCode.missingReadmeLink,
            path: 'README.md',
            message: 'README.md does not reference ${check.substring(8)}.',
          ),
        );
      }
    }

    if (!request.labelsAvailable) {
      findings.add(
        const AiroRepositoryHealthFinding(
          code: AiroRepositoryHealthFindingCode.labelSourceUnavailable,
          blocking: false,
          message:
              'Repository labels could not be read locally; rerun with gh auth '
              'or pass explicit labels for final evidence.',
        ),
      );
    } else {
      for (final label in requiredLabels) {
        if (!request.labels.contains(label.toLowerCase())) {
          findings.add(
            AiroRepositoryHealthFinding(
              code: AiroRepositoryHealthFindingCode.missingLabel,
              label: label,
              message: 'Required repository label is missing: $label.',
            ),
          );
        }
      }
    }

    if (request.discussionsDecision == AiroRepositoryDecision.unknown) {
      findings.add(
        const AiroRepositoryHealthFinding(
          code: AiroRepositoryHealthFindingCode.discussionsDecisionMissing,
          message:
              'Maintainer must decide whether GitHub Discussions are required '
              'or intentionally deferred for this release wave.',
        ),
      );
    }

    if (request.codeownersPresent &&
        request.codeownersDecision == AiroRepositoryDecision.unknown) {
      findings.add(
        const AiroRepositoryHealthFinding(
          code: AiroRepositoryHealthFindingCode.codeownersDecisionMissing,
          message:
              'CODEOWNERS exists, but maintainer ownership decision must be '
              'recorded for release, security, docs, and v2 platform paths.',
        ),
      );
    } else if (!request.codeownersPresent) {
      if (request.codeownersDecision == AiroRepositoryDecision.present) {
        findings.add(
          const AiroRepositoryHealthFinding(
            code: AiroRepositoryHealthFindingCode.codeownersRequiredButMissing,
            message:
                'CODEOWNERS was marked required/present, but no CODEOWNERS file '
                'exists in the repository.',
          ),
        );
      } else if (request.codeownersDecision == AiroRepositoryDecision.unknown) {
        findings.add(
          const AiroRepositoryHealthFinding(
            code: AiroRepositoryHealthFindingCode.codeownersDecisionMissing,
            message:
                'Maintainer must provide CODEOWNERS entries or explicitly mark '
                'CODEOWNERS not required for this release wave.',
          ),
        );
      }
    }

    if (request.fundingPresent &&
        request.fundingDecision == AiroRepositoryDecision.unknown) {
      findings.add(
        const AiroRepositoryHealthFinding(
          code: AiroRepositoryHealthFindingCode.fundingDecisionMissing,
          message:
              'Funding metadata exists, but maintainer funding/sponsor policy '
              'must be recorded for public release.',
        ),
      );
    } else if (!request.fundingPresent) {
      if (request.fundingDecision == AiroRepositoryDecision.present) {
        findings.add(
          const AiroRepositoryHealthFinding(
            code: AiroRepositoryHealthFindingCode.fundingRequiredButMissing,
            message:
                'Funding metadata was marked required/present, but no '
                '.github/FUNDING.yml file exists.',
          ),
        );
      } else if (request.fundingDecision == AiroRepositoryDecision.unknown) {
        findings.add(
          const AiroRepositoryHealthFinding(
            code: AiroRepositoryHealthFindingCode.fundingDecisionMissing,
            message:
                'Maintainer must add funding metadata or confirm it is '
                'intentionally absent for this release wave.',
          ),
        );
      }
    }

    final presentLabels = request.labels.toList()..sort();
    return AiroRepositoryHealthPreflight(
      requiredFiles: request.requiredFiles,
      issueTemplates: request.issueTemplates,
      requiredLabels: requiredLabels,
      presentLabels: presentLabels,
      labelsAvailable: request.labelsAvailable,
      codeownersPresent: request.codeownersPresent,
      fundingPresent: request.fundingPresent,
      discussionsDecision: request.discussionsDecision,
      codeownersDecision: request.codeownersDecision,
      fundingDecision: request.fundingDecision,
      findings: findings,
    );
  }
}
