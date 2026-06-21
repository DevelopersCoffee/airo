import 'package:airo_app/features/agent_chat/domain/services/agent_skill_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AgentSkillRegistry persistence', () {
    test(
      'persists individual skill enablement across registry instances',
      () async {
        SharedPreferences.setMockInitialValues({});

        final first = await AgentSkillRegistry.loadPersisted();
        first.setSkillEnabled('read-calendar-events', false);

        final second = await AgentSkillRegistry.loadPersisted();

        expect(second.getById('read-calendar-events')?.isEnabled, false);
        expect(second.getById('schedule-notification')?.isEnabled, true);
      },
    );

    test('persists enable all and disable all state', () async {
      SharedPreferences.setMockInitialValues({});

      final first = await AgentSkillRegistry.loadPersisted();
      first.disableAll();
      expect(first.getEnabledSkills(), isEmpty);

      final disabled = await AgentSkillRegistry.loadPersisted();
      expect(disabled.getEnabledSkills(), isEmpty);

      disabled.enableAll();
      final enabled = await AgentSkillRegistry.loadPersisted();

      expect(
        enabled.getEnabledSkills().map((skill) => skill.id),
        enabled.getAllSkills().map((skill) => skill.id),
      );
    });
  });
}
