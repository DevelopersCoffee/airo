import 'package:feature_mind/src/agent_chat/domain/models/agent_plugin_catalog.dart';
import 'package:feature_mind/src/agent_chat/domain/models/agent_skill.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_skill_registry.dart';
import 'package:feature_mind/src/agent_chat/presentation/widgets/pick_assistant_sheet.dart';
import 'package:feature_mind/src/runtime/models/capability_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/plugin_skill_fixture.dart';

void main() {
  testWidgets('assistant sheet pins an installed teacher plugin', (
    tester,
  ) async {
    final registry = AgentSkillRegistry(
      skills: [
        ...AgentSkillRegistry.builtInSkills,
        loadPluginSkillFixture('lesson-planning-assistant'),
      ],
    );
    String? pinned;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickAssistantSheet(
            registry: registry,
            pinnedPersonaId: pinned,
            catalog: const AgentPluginCatalog([]),
            onPinnedChanged: (id) => pinned = id,
          ),
        ),
      ),
    );

    expect(find.text('Assistants'), findsOneWidget);
    expect(find.text('Normal chat'), findsOneWidget);
    expect(find.text('Lesson Planning'), findsOneWidget);
    expect(find.text('Hospital Recovery'), findsNothing);

    await tester.tap(
      find.byKey(const Key('pick_assistant_lesson-planning-assistant')),
    );
    await tester.pumpAndSettle();
    expect(pinned, 'lesson-planning-assistant');
  });

  testWidgets('assistant sheet installs a catalog plugin', (tester) async {
    final registry = AgentSkillRegistry();
    AgentPluginCatalogEntry? installed;
    const entry = AgentPluginCatalogEntry(
      id: 'hospital-recovery-planner',
      name: 'Hospital Recovery',
      description: 'Stage a surgery or hospital stay.',
      version: '1.0.0',
      family: AgentPersonaFamily.health,
      safetyClass: CapabilitySafetyClass.health,
      author: 'Airo',
      url: 'https://example.com/hospital-recovery-planner/SKILL.md',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickAssistantSheet(
            registry: registry,
            pinnedPersonaId: null,
            catalog: const AgentPluginCatalog([entry]),
            onPinnedChanged: (_) {},
            onInstall: (selected) async {
              installed = selected;
              registry.replaceSkill(
                loadPluginSkillFixture('hospital-recovery-planner'),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Available to install'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('pick_assistant_install_hospital-recovery-planner')),
    );
    await tester.pumpAndSettle();
    expect(installed?.id, 'hospital-recovery-planner');
  });
}
