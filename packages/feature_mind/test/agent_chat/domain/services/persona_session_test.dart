import 'package:feature_mind/src/agent_chat/data/built_in_skills/draft_diet_plan.dart';
import 'package:feature_mind/src/agent_chat/data/built_in_skills/insurance_planner.dart';
import 'package:feature_mind/src/agent_chat/data/built_in_skills/law_personas.dart';
import 'package:feature_mind/src/agent_chat/data/built_in_skills/life_workflow_personas.dart';
import 'package:feature_mind/src/agent_chat/data/built_in_skills/teacher_personas.dart';
import 'package:feature_mind/src/agent_chat/domain/models/agent_skill.dart';
import 'package:feature_mind/src/agent_chat/domain/services/persona_session.dart';
import 'package:feature_mind/src/runtime/models/capability_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PersonaSession', () {
    test('unpinned chat has no exclusive playbook', () {
      const session = PersonaSession();
      expect(session.isPinned, isFalse);
      expect(session.playbooks(), isEmpty);
      expect(session.identityPreamble(), isEmpty);
      expect(session.starterPrompts, isEmpty);
    });

    test('pinned teacher owns the conversation voice', () {
      final session = PersonaSession(pinned: lessonPlanningAssistant);
      expect(session.isPinned, isTrue);
      expect(session.pinnedId, 'lesson-planning-assistant');
      expect(session.playbooks().single, contains('lesson outline'));
      expect(session.identityPreamble(), contains('Lesson Planning'));
      expect(session.identityPreamble(), contains('private on-device'));
      expect(session.starterPrompts, isNotEmpty);
      expect(session.safetyClass, isNull);
    });

    test('law persona carries the legal safety class', () {
      final session = PersonaSession(pinned: contractReviewAssistant);
      expect(session.safetyClass, CapabilitySafetyClass.legal);
      expect(
        session.playbooks().single,
        contains('Do not provide legal advice'),
      );
    });

    test('diet persona carries the health safety class', () {
      final session = PersonaSession(pinned: draftDietPlanSkill);
      expect(session.safetyClass, CapabilitySafetyClass.health);
      expect(draftDietPlanSkill.isPersona, isTrue);
      expect(draftDietPlanSkill.family, AgentPersonaFamily.health);
    });

    test('insurance planner declares follow-up and LifeTrack tools', () {
      final session = PersonaSession(pinned: insurancePlannerPersona);
      expect(session.safetyClass, CapabilitySafetyClass.financial);
      expect(session.usesTool('query_lifetrack_status'), isTrue);
      expect(
        insurancePlannerPersona.followUpPolicy,
        SkillFollowUpPolicy.offerCalendar,
      );
      expect(insurancePlannerPersona.lifeTrackTemplateId, 'insurance_claim_v1');
      expect(
        session.playbooks().join('\n'),
        contains('offer to add deadlines'),
      );
      expect(session.playbooks().join('\n'), contains('insurance_claim_v1'));
    });

    test(
      'life-workflow personas cover hospital, admission, car, and project',
      () {
        expect(hospitalRecoveryPersona.family, AgentPersonaFamily.health);
        expect(
          hospitalRecoveryPersona.lifeTrackTemplateId,
          'medical_surgery_v1',
        );
        expect(
          hospitalRecoveryPersona.followUpPolicy,
          SkillFollowUpPolicy.dailyUntilDone,
        );
        expect(universityAdmissionPersona.family, AgentPersonaFamily.education);
        expect(carPurchasePersona.family, AgentPersonaFamily.vehicle);
        expect(carPurchasePersona.safetyClass, CapabilitySafetyClass.financial);
        expect(projectPlannerPersona.family, AgentPersonaFamily.project);
        expect(projectPlannerPersona.isGenerativePlugin, isTrue);
        expect(
          PersonaSession(pinned: projectPlannerPersona).playbooks().join('\n'),
          contains('daily reminder'),
        );
      },
    );

    test('grading assistant refuses to assign grades', () {
      expect(
        gradingSupportAssistant.instructions,
        contains('Do not assign final grades'),
      );
    });
  });
}
