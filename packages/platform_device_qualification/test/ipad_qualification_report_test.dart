import 'package:flutter_test/flutter_test.dart';
import 'package:platform_device_qualification/platform_device_qualification.dart';

void main() {
  group('iPad qualification report', () {
    IpadQualificationReport build({
      Map<String, IpadQualificationPhaseStatus>? statuses,
      Map<String, int> defectCounts = const {},
    }) {
      return const IpadQualificationReportBuilder().build(
        reportId: 'manual-ipad-air-001',
        campaignId: 'issue-716-ipad-air',
        deviceName: 'iPad Air',
        appProfile: 'Airo TV qualification',
        playlistProfile: 'iptv-org-public',
        phaseStatuses:
            statuses ??
            {
              for (final phase in kDefaultIpadQualificationPhases)
                phase.id: IpadQualificationPhaseStatus.passed,
            },
        defectCounts: defectCounts,
      );
    }

    test('marks a complete all-pass campaign as issue evidence ready', () {
      final report = build();

      expect(report.completeForIssueEvidence, isTrue);
      expect(report.passedCount, kDefaultIpadQualificationPhases.length);
      expect(report.failedCount, 0);
      expect(report.waivedCount, 0);
      expect(report.missingCount, 0);
      expect(report.defectCount, 0);
      expect(report.findings, isEmpty);
      expect(report.toPublicMap()['reportId'], 'manual-ipad-air-001');
    });

    test('missing phases block completion', () {
      final report = build(statuses: const {});

      expect(report.completeForIssueEvidence, isFalse);
      expect(report.missingCount, kDefaultIpadQualificationPhases.length);
      expect(
        report.findings.map((finding) => finding.code),
        everyElement('missing_phase_evidence'),
      );
    });

    test('failed phases and unwaived defects block completion', () {
      final statuses = {
        for (final phase in kDefaultIpadQualificationPhases)
          phase.id: IpadQualificationPhaseStatus.passed,
        'phase1_video_player': IpadQualificationPhaseStatus.failed,
      };
      final report = build(
        statuses: statuses,
        defectCounts: const {'phase1_video_player': 2},
      );

      expect(report.completeForIssueEvidence, isFalse);
      expect(report.failedCount, 1);
      expect(report.defectCount, 2);
      expect(
        report.findings.map((finding) => finding.code),
        containsAll(const {'failed_phase', 'unwaived_defects'}),
      );
    });

    test('waived phases can complete when defects are recorded', () {
      final statuses = {
        for (final phase in kDefaultIpadQualificationPhases)
          phase.id: IpadQualificationPhaseStatus.passed,
        'phase5_network_profiles': IpadQualificationPhaseStatus.waived,
      };
      final report = build(
        statuses: statuses,
        defectCounts: const {'phase5_network_profiles': 1},
      );

      expect(report.completeForIssueEvidence, isTrue);
      expect(report.waivedCount, 1);
      expect(report.defectCount, 1);
      expect(report.findings, isEmpty);
    });

    test('public output omits raw playlist URLs', () {
      final report = const IpadQualificationReportBuilder().build(
        reportId: 'manual-ipad-air-001',
        campaignId: 'issue-716-ipad-air',
        deviceName: 'iPad Air',
        appProfile: 'Airo TV qualification',
        playlistProfile: 'iptv-org-public',
        phaseStatuses: {'phase1_splash': IpadQualificationPhaseStatus.passed},
      );

      final output = report.toPublicMap().toString();

      expect(output, contains('iptv-org-public'));
      expect(output, isNot(contains('https://')));
      expect(output, isNot(contains('user_playlist_url')));
    });
  });
}
