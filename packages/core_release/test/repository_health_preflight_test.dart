import 'package:core_release/core_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo repository health preflight', () {
    AiroRepositoryHealthPreflight run({
      Iterable<AiroRepositoryFileStatus> requiredFiles = const [
        AiroRepositoryFileStatus(path: 'README.md', present: true),
        AiroRepositoryFileStatus(path: 'SECURITY.md', present: true),
      ],
      Iterable<AiroRepositoryFileStatus> issueTemplates = const [
        AiroRepositoryFileStatus(
          path: '.github/ISSUE_TEMPLATE/user_bug_report.md',
          present: true,
        ),
      ],
      Iterable<String> readmeTextChecks = const [
        'present:.github/workflows/release-orchestrator.yml',
        'present:docs/release/V2_RELEASE_ORCHESTRATOR.md',
      ],
      Iterable<String> labels =
          AiroRepositoryHealthPreflightRunner.requiredLabels,
      bool labelsAvailable = true,
      bool codeownersPresent = true,
      bool fundingPresent = true,
      AiroRepositoryDecision discussionsDecision =
          AiroRepositoryDecision.enabled,
      AiroRepositoryDecision codeownersDecision =
          AiroRepositoryDecision.present,
      AiroRepositoryDecision fundingDecision = AiroRepositoryDecision.present,
    }) {
      return const AiroRepositoryHealthPreflightRunner().run(
        AiroRepositoryHealthPreflightRequest(
          requiredFiles: requiredFiles,
          issueTemplates: issueTemplates,
          readmeTextChecks: readmeTextChecks,
          labels: labels,
          labelsAvailable: labelsAvailable,
          codeownersPresent: codeownersPresent,
          fundingPresent: fundingPresent,
          discussionsDecision: discussionsDecision,
          codeownersDecision: codeownersDecision,
          fundingDecision: fundingDecision,
        ),
      );
    }

    test('accepts repository health when files labels and decisions exist', () {
      final preflight = run();

      expect(preflight.ready, isTrue);
      expect(preflight.findings, isEmpty);
    });

    test('blocks missing required files and issue templates', () {
      final preflight = run(
        requiredFiles: const [
          AiroRepositoryFileStatus(path: 'README.md', present: false),
        ],
        issueTemplates: const [
          AiroRepositoryFileStatus(
            path: '.github/ISSUE_TEMPLATE/question.yml',
            present: false,
          ),
        ],
      );

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        containsAll([
          AiroRepositoryHealthFindingCode.missingRequiredFile,
          AiroRepositoryHealthFindingCode.missingIssueTemplate,
        ]),
      );
    });

    test('blocks missing README links', () {
      final preflight = run(
        readmeTextChecks: const [
          'missing:docs/release/V2_PUBLISHING_HUMAN_SETUP.md',
        ],
      );

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.single.code,
        AiroRepositoryHealthFindingCode.missingReadmeLink,
      );
    });

    test('blocks missing labels when labels are available', () {
      final preflight = run(labels: const ['store-readiness']);

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroRepositoryHealthFindingCode.missingLabel),
      );
    });

    test('warns but does not block when labels cannot be read locally', () {
      final preflight = run(labels: const [], labelsAvailable: false);

      expect(preflight.ready, isTrue);
      expect(
        preflight.findings.single.code,
        AiroRepositoryHealthFindingCode.labelSourceUnavailable,
      );
      expect(preflight.findings.single.blocking, isFalse);
    });

    test('blocks missing maintainer governance decisions', () {
      final preflight = run(
        codeownersPresent: false,
        fundingPresent: false,
        discussionsDecision: AiroRepositoryDecision.unknown,
        codeownersDecision: AiroRepositoryDecision.unknown,
        fundingDecision: AiroRepositoryDecision.unknown,
      );

      expect(preflight.ready, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        containsAll([
          AiroRepositoryHealthFindingCode.discussionsDecisionMissing,
          AiroRepositoryHealthFindingCode.codeownersDecisionMissing,
          AiroRepositoryHealthFindingCode.fundingDecisionMissing,
        ]),
      );
    });

    test('accepts explicit CODEOWNERS and funding deferrals', () {
      final preflight = run(
        codeownersPresent: false,
        fundingPresent: false,
        codeownersDecision: AiroRepositoryDecision.notRequired,
        fundingDecision: AiroRepositoryDecision.intentionallyAbsent,
      );

      expect(preflight.ready, isTrue);
    });

    test('renders markdown findings for issue evidence', () {
      final markdown = run(
        discussionsDecision: AiroRepositoryDecision.unknown,
      ).toMarkdown();

      expect(markdown, contains('# Repository Health Preflight'));
      expect(markdown, contains('discussions_decision_missing'));
    });
  });
}
