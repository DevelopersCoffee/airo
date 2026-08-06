import 'package:feature_assistant/src/agent_chat/presentation/screens/model_advisor_screen.dart';
import 'package:feature_assistant/src/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('recommends a model by task capability', (tester) async {
    final semantics = tester.ensureSemantics();
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final data = Map<String, dynamic>.from(call.arguments as Map);
          copiedText = data['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
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
    expect(
      find.bySemanticsLabel('Capability: Chat. Selected.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Recommended model Mock Chat Project. Runtime MockRuntime. '
        'Prompt stays on device. 1 MB. Ready.',
      ),
      findsOneWidget,
    );
    expect(find.text('Copy recommendation'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp('Copy recommendation for Mock Chat Project'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Copy recommendation'));
    await tester.pump();

    expect(find.text('Recommendation copied.'), findsOneWidget);
    expect(copiedText, contains('# Airo Model Advisor Recommendation'));
    expect(copiedText, contains('| Capability | `Chat` |'));
    expect(copiedText, contains('| Device | `Pixel 9` |'));
    expect(copiedText, contains('| Platform | `Android` |'));
    expect(copiedText, contains('| Runtime | `MockRuntime` |'));
    expect(copiedText, contains('- MockRuntime is ready for this capability.'));
    expect(copiedText, isNot(contains('/Users/')));
    expect(copiedText, isNot(contains('/storage/')));
    ScaffoldMessenger.of(
      tester.element(find.text('Model Advisor')),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Image'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Recommended for Image'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Capability: Image. Selected.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Use this model'));
    await tester.pumpAndSettle();

    expect(find.text('Selected: mock-image'), findsOneWidget);
    semantics.dispose();
  });
}
