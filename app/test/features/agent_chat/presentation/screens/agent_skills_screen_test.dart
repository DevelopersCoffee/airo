import 'package:airo_app/features/agent_chat/presentation/screens/agent_skills_screen.dart';
import 'package:airo_app/features/agent_chat/domain/services/agent_skill_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows built-in skills and lets users toggle one', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AgentSkillsScreen(
          registryFuture: Future.value(AgentSkillRegistry()),
        ),
      ),
    );
    // The loading indicator is continuously animated, so settling the whole
    // tree would wait forever even after the registry has loaded.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Agent Skills'), findsOneWidget);
    expect(find.text('Give Airo useful tools'), findsOneWidget);
    expect(find.textContaining('skills enabled'), findsOneWidget);
    expect(find.byType(Switch), findsWidgets);

    final firstSwitch = find.byType(Switch).first;
    final before = tester.widget<Switch>(firstSwitch).value;
    await tester.tap(firstSwitch);
    await tester.pump();
    expect(
      tester.widget<Switch>(find.byType(Switch).first).value,
      isNot(before),
    );
  });
}
