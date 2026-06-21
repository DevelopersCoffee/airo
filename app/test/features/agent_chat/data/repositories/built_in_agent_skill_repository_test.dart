import 'package:airo_app/features/agent_chat/data/repositories/built_in_agent_skill_repository.dart';
import 'package:airo_app/features/agent_chat/domain/models/agent_skill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BuiltInAgentSkillRepository', () {
    test('returns built-in skills and filters enabled summaries for prompts', () {
      final repository = BuiltInAgentSkillRepository(
        skills: [_calendarSkill(), _routeSkill(enabled: false)],
      );

      expect(repository.getAllSkills(), hasLength(2));
      expect(repository.getEnabledSkills().map((skill) => skill.id), [
        'calendar-today',
      ]);
      expect(repository.enabledSkillSummariesForPrompt(), [
        '- calendar-today: Calendar Today — Check schedule. Tools: get_current_date_time, read_calendar_events',
      ]);
    });

    test('searches by id, name, description, tool, and capability', () {
      final repository = BuiltInAgentSkillRepository(
        skills: [_calendarSkill(), _routeSkill()],
      );

      expect(repository.search('calendar').map((skill) => skill.id), [
        'calendar-today',
      ]);
      expect(repository.search('route.open').map((skill) => skill.id), [
        'open-airo-feature',
      ]);
      expect(repository.search('open_route').map((skill) => skill.id), [
        'open-airo-feature',
      ]);
      expect(repository.search('feature').map((skill) => skill.id), [
        'open-airo-feature',
      ]);
    });

    test('can enable all and disable all built-in skills', () {
      final repository = BuiltInAgentSkillRepository(
        skills: [_calendarSkill(), _routeSkill(enabled: false)],
      );

      repository.enableAll();
      expect(repository.getEnabledSkills().map((skill) => skill.id), [
        'calendar-today',
        'open-airo-feature',
      ]);

      repository.disableAll();
      expect(repository.getEnabledSkills(), isEmpty);
    });

    test('sets individual skill enablement without mutating manifest data', () {
      final repository = BuiltInAgentSkillRepository(
        skills: [_calendarSkill()],
      );

      repository.setSkillEnabled('calendar-today', false);

      final skill = repository.getById('calendar-today')!;
      expect(skill.isEnabled, false);
      expect(skill.manifest.installState, SkillInstallState.disabled);
      expect(skill.manifest.source, SkillSource.builtIn);
    });
  });
}

AgentSkill _calendarSkill({bool enabled = true}) {
  return AgentSkill.fromManifest(
    manifest: AgentSkillManifest(
      id: 'calendar-today',
      name: 'Calendar Today',
      description: 'Check schedule.',
      version: '1.0.0',
      author: 'Airo',
      runtime: SkillRuntime.native,
      source: SkillSource.builtIn,
      installState: enabled
          ? SkillInstallState.enabled
          : SkillInstallState.disabled,
      capabilities: const [SkillCapability.calendarRead],
      tools: const ['get_current_date_time', 'read_calendar_events'],
    ),
    instructions: 'Use this for calendar questions.',
  );
}

AgentSkill _routeSkill({bool enabled = true}) {
  return AgentSkill.fromManifest(
    manifest: AgentSkillManifest(
      id: 'open-airo-feature',
      name: 'Open Airo Feature',
      description: 'Open app routes.',
      version: '1.0.0',
      author: 'Airo',
      runtime: SkillRuntime.native,
      source: SkillSource.builtIn,
      installState: enabled
          ? SkillInstallState.enabled
          : SkillInstallState.disabled,
      capabilities: const [SkillCapability.routeOpen],
      tools: const ['open_route'],
    ),
    instructions: 'Open app features.',
  );
}
