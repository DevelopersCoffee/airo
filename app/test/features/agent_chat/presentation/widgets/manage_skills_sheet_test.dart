import 'package:airo_app/features/agent_chat/domain/services/agent_skill_registry.dart';
import 'package:airo_app/features/agent_chat/presentation/widgets/manage_skills_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manage skills sheet searches visible skills', (tester) async {
    final semantics = tester.ensureSemantics();
    final registry = AgentSkillRegistry();

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManageSkillsSheet(registry: registry, onChanged: () {}),
          ),
        ),
      );

      expect(find.text('Manage Skills'), findsOneWidget);
      expect(find.bySemanticsLabel('Search skills'), findsOneWidget);
      expect(find.text('5 skills'), findsOneWidget);
      expect(find.text('read-calendar-events'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Open Airo');
      await tester.pump();

      expect(find.text('open-airo-feature'), findsOneWidget);
      expect(find.text('read-calendar-events'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('manage skills toggles expose skill name and state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final registry = AgentSkillRegistry();

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManageSkillsSheet(registry: registry, onChanged: () {}),
          ),
        ),
      );

      final createEventToggle = find.bySemanticsLabel(
        'Create Calendar Event skill',
      );
      expect(createEventToggle, findsOneWidget);
      expect(tester.getSemantics(createEventToggle).value, 'Disabled');

      await tester.tap(createEventToggle);
      await tester.pump();

      expect(tester.getSemantics(createEventToggle).value, 'Enabled');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'manage skills sheet toggles registry state and notifies changes',
    (tester) async {
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
    },
  );
}
