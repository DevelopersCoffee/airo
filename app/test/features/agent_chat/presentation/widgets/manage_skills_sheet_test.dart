import 'package:airo_app/features/agent_chat/domain/services/agent_skill_registry.dart';
import 'package:airo_app/features/agent_chat/presentation/widgets/manage_skills_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manage skills sheet searches visible skills', (tester) async {
    final registry = AgentSkillRegistry();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManageSkillsSheet(registry: registry, onChanged: () {}),
        ),
      ),
    );

    expect(find.text('Manage Skills'), findsOneWidget);
    expect(find.text('4 skills'), findsOneWidget);
    expect(find.text('read-calendar-events'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Open Airo');
    await tester.pump();

    expect(find.text('open-airo-feature'), findsOneWidget);
    expect(find.text('read-calendar-events'), findsNothing);
  });

  testWidgets('manage skills sheet toggles registry state and notifies changes', (
    tester,
  ) async {
    final registry = AgentSkillRegistry();
    var changedCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManageSkillsSheet(
            registry: registry,
            onChanged: () => changedCount++,
          ),
        ),
      ),
    );

    expect(registry.getById('create-calendar-event')?.enabled, false);

    await tester.tap(find.byType(Switch).at(1));
    await tester.pump();

    expect(registry.getById('create-calendar-event')?.enabled, true);
    expect(changedCount, 1);
  });
}
