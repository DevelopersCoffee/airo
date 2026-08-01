import 'package:airo_app/features/agent_chat/presentation/screens/model_advisor_screen.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('recommends a model by task capability', (tester) async {
    String selected = 'none';
    Future<AssistantModelLibraryState> load(AssistantTask task) async {
      final candidate = AssistantModelCandidate(
        id: 'mock-${task.name}',
        name: 'Mock ${task.label}',
        runtime: 'MockRuntime',
        description: 'Deterministic model for ${task.label}.',
        bestFor: [task],
        tags: const ['Local', 'Tested'],
        privacyLabel: 'Prompt stays on device',
        sizeLabel: '1 MB',
        available: true,
        actionLabel: 'Use this model',
        local: true,
      );
      return AssistantModelLibraryState(
        task: task,
        deviceLabel: 'Pixel 9',
        platformLabel: 'Android',
        candidates: [candidate],
        recommended: candidate,
        defaultPackages: const {},
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Column(
                children: [
                  Text('Selected: $selected'),
                  FilledButton(
                    onPressed: () async {
                      final candidate = await Navigator.of(context)
                          .push<AssistantModelCandidate>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ModelAdvisorScreen(loadRecommendation: load),
                            ),
                          );
                      if (candidate != null) {
                        setState(() => selected = candidate.id);
                      }
                    },
                    child: const Text('Open advisor'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open advisor'));
    await tester.pumpAndSettle();

    expect(find.text('Model Advisor'), findsOneWidget);
    expect(find.text('What do you want to do?'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Thinking'), findsOneWidget);
    expect(find.text('Why this choice'), findsOneWidget);

    await tester.tap(find.text('Image'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Recommended for Image'), findsOneWidget);
    await tester.tap(find.text('Use this model'));
    await tester.pumpAndSettle();

    expect(find.text('Selected: mock-image'), findsOneWidget);
  });
}
