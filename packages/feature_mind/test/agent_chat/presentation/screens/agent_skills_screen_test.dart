import 'dart:async';

import 'package:feature_mind/src/agent_chat/presentation/screens/agent_skills_screen.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_skill_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows loading state while skills load', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AgentSkillsScreen(
          registryFuture: Completer<AgentSkillRegistry>().future,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows load failure state', (tester) async {
    final registryCompleter = Completer<AgentSkillRegistry>();

    await tester.pumpWidget(
      MaterialApp(
        home: AgentSkillsScreen(registryFuture: registryCompleter.future),
      ),
    );
    await tester.pump();
    registryCompleter.completeError(StateError('skill store unavailable'));
    await tester.pump();

    expect(
      find.textContaining(
        'Could not load skills: Bad state: skill store unavailable',
      ),
      findsOneWidget,
    );
  });

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

  testWidgets('invalid remote skill imports show an inline error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AgentSkillsScreen(
          registryFuture: Future.value(AgentSkillRegistry()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byType(TextField),
      'ftp://example.com/SKILL.md',
    );
    await tester.tap(find.text('Import skill'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Only HTTPS'), findsWidgets);
  });
}
