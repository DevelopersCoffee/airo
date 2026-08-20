import 'package:feature_mind/src/agent_chat/domain/services/agent_skill_registry.dart';
import 'package:feature_mind/src/agent_chat/presentation/widgets/pick_assistant_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('assistant sheet pins a teacher persona', (tester) async {
    final registry = AgentSkillRegistry();
    String? pinned;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickAssistantSheet(
            registry: registry,
            pinnedPersonaId: pinned,
            onPinnedChanged: (id) => pinned = id,
          ),
        ),
      ),
    );

    expect(find.text('Assistants'), findsOneWidget);
    expect(find.text('Normal chat'), findsOneWidget);
    expect(find.text('Diet Plan'), findsOneWidget);
    expect(find.text('Hospital Recovery'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('pick_assistant_lesson-planning-assistant')),
      300,
    );
    await tester.tap(
      find.byKey(const Key('pick_assistant_lesson-planning-assistant')),
    );
    await tester.pumpAndSettle();
    expect(pinned, 'lesson-planning-assistant');
  });
}
