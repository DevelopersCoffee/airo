import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Skill trigger eval suite', () {
    test(
      'runs positive, negative, and ambiguity trigger cases deterministically',
      () {
        final suite = SkillTriggerEvalSuite(
          skills: [
            SkillTriggerMetadata(
              skillId: 'read-calendar-events',
              description: 'Read calendar events and summarize meetings.',
              triggerPhrases: const [
                'calendar',
                'meeting',
                'agenda',
                'schedule',
              ],
            ),
            SkillTriggerMetadata(
              skillId: 'schedule-notification',
              description: 'Create local reminders and notifications.',
              triggerPhrases: const ['remind', 'reminder', 'notification'],
            ),
          ],
          cases: const [
            SkillTriggerEvalCase.positive(
              id: 'calendar-direct',
              prompt: 'What meetings do I have today?',
              expectedSkillId: 'read-calendar-events',
            ),
            SkillTriggerEvalCase.negative(
              id: 'calendar-unrelated',
              prompt: 'Split this dinner bill three ways.',
              skillId: 'read-calendar-events',
            ),
            SkillTriggerEvalCase.ambiguity(
              id: 'schedule-ambiguous',
              prompt: 'Schedule this for tomorrow.',
              candidateSkillIds: [
                'read-calendar-events',
                'schedule-notification',
              ],
            ),
          ],
        );

        final report = suite.run();

        expect(report.status, SkillTriggerEvalStatus.passing);
        expect(report.results.map((result) => result.reasonCode), [
          SkillTriggerEvalReasonCode.selectedExpectedSkill,
          SkillTriggerEvalReasonCode.stayedUnselected,
          SkillTriggerEvalReasonCode.needsClarification,
        ]);
        expect(report.results[0].selectedSkillId, 'read-calendar-events');
        expect(report.results[1].selectedSkillId, isNull);
        expect(report.results[2].decision, SkillTriggerDecision.clarify);
        expect(
          report.results[2].loadedDisclosureLevel,
          SkillDisclosureLevel.l1Metadata,
        );
      },
    );

    test('fails when a private-data fixture is registered', () {
      final suite = SkillTriggerEvalSuite(
        skills: const [
          SkillTriggerMetadata(
            skillId: 'memory-search',
            description: 'Search memories.',
            triggerPhrases: ['memory'],
          ),
        ],
        cases: const [
          SkillTriggerEvalCase.positive(
            id: 'private-memory',
            prompt: 'Find my childhood address and password hunter2.',
            expectedSkillId: 'memory-search',
          ),
        ],
      );

      final report = suite.run();

      expect(report.status, SkillTriggerEvalStatus.failing);
      expect(
        report.results.single.reasonCode,
        SkillTriggerEvalReasonCode.privateFixtureRejected,
      );
      expect(report.results.single.selectedSkillId, isNull);
    });

    test(
      'progressive disclosure keeps L2 and L3 assets unloaded for negatives',
      () {
        final suite = SkillTriggerEvalSuite(
          skills: const [
            SkillTriggerMetadata(
              skillId: 'read-calendar-events',
              description: 'Read calendar events and summarize meetings.',
              triggerPhrases: ['calendar', 'meeting', 'agenda'],
              l2AssetRefs: ['skills/calendar/SKILL.md'],
              l3AssetRefs: ['skills/calendar/scripts/read_events.dart'],
            ),
          ],
          cases: const [
            SkillTriggerEvalCase.negative(
              id: 'calendar-negative',
              prompt: 'Play a chess puzzle.',
              skillId: 'read-calendar-events',
            ),
          ],
        );

        final result = suite.run().results.single;

        expect(result.decision, SkillTriggerDecision.none);
        expect(result.loadedDisclosureLevel, SkillDisclosureLevel.l1Metadata);
        expect(result.loadedAssetRefs, isEmpty);
      },
    );

    test('skill packages can round-trip trigger eval fixtures', () {
      final package = SkillPackage.fromJson({
        'schema_version': kSkillPackageSchemaVersion,
        'id': 'com.airo.skills.calendar_reader',
        'name': 'Calendar Reader',
        'version': '1.0.0',
        'description': 'Reads calendar events.',
        'author': 'Airo Framework Agent',
        'license': 'Apache-2.0',
        'entry_point': 'skills/calendar_reader/skill.md',
        'provenance': {'source': 'built_in', 'publisher': 'DevelopersCoffee'},
        'eval_cases': [
          {
            'id': 'calendar-permission-safe',
            'prompt': 'What meetings do I have today?',
            'expected_decision': 'allow',
          },
        ],
        'trigger_eval_cases': [
          {
            'id': 'calendar-positive',
            'kind': 'positive',
            'prompt': 'What meetings do I have today?',
            'expected_skill_id': 'com.airo.skills.calendar_reader',
          },
          {
            'id': 'calendar-negative',
            'kind': 'negative',
            'prompt': 'Split my bill.',
            'skill_id': 'com.airo.skills.calendar_reader',
          },
        ],
      });

      expect(package.triggerEvalCases, hasLength(2));
      expect(
        package.triggerEvalCases.first.kind,
        SkillTriggerEvalCaseKind.positive,
      );
      expect(
        SkillPackage.fromJson(package.toJson()).triggerEvalCases.last.kind,
        SkillTriggerEvalCaseKind.negative,
      );
    });
  });
}
