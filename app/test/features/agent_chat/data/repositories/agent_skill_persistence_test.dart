import 'package:airo_app/features/agent_chat/data/repositories/shared_preferences_agent_skill_state_store.dart';
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

  group('SharedPreferencesAgentSkillStateStore', () {
    test('persists enabled state through guarded preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesAgentSkillStateStore(prefs);

      await store.saveEnabledState({
        'read-calendar-events': false,
        'schedule-notification': true,
      });

      expect(prefs.getString('agent_skills.enabled_state.v1'), isNotNull);
      expect(store.loadEnabledState(), {
        'read-calendar-events': false,
        'schedule-notification': true,
      });
    });

    test('drops oversized enabled state before persisting raw JSON', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesAgentSkillStateStore(
        prefs,
        maxPreferenceValueBytes: 96,
      );

      await store.saveEnabledState({'read-calendar-events': false});
      expect(prefs.getString('agent_skills.enabled_state.v1'), isNotNull);

      await store.saveEnabledState({
        for (var i = 0; i < 32; i++) 'skill-with-a-long-id-$i': i.isEven,
      });

      expect(prefs.getString('agent_skills.enabled_state.v1'), isNull);
      expect(store.loadEnabledState(), isEmpty);
    });
  });
}
