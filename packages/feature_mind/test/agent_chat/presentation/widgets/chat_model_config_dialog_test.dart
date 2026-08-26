import 'package:feature_mind/src/agent_chat/domain/models/chat_model_config.dart';
import 'package:feature_mind/src/agent_chat/presentation/widgets/chat_model_config_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> _setPhoneSurface(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
  }

  testWidgets('shows model config controls and returns edited values', (
    tester,
  ) async {
    await _setPhoneSurface(tester);
    late ChatModelConfig? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showChatModelConfigDialog(
                    context: context,
                    initial: ChatModelConfig.defaults,
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Configurations'), findsOneWidget);
    expect(find.text('Model Configs'), findsOneWidget);
    expect(find.text('System Prompt'), findsOneWidget);
    expect(find.text('Max Tokens'), findsOneWidget);
    expect(find.text('TopK'), findsOneWidget);
    expect(find.text('TopP'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Accelerator'), findsOneWidget);
    expect(find.text('GPU'), findsOneWidget);

    await tester.tap(find.text('CPU'));
    await tester.pumpAndSettle();

    final maxTokensField = find.descendant(
      of: find.byKey(const Key('chat_model_config_max_tokens')),
      matching: find.byType(TextField),
    );
    await tester.enterText(maxTokensField, '512');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.text('System Prompt'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chat_model_config_system_prompt')),
      'Reply in one sentence.',
    );

    await tester.tap(find.byKey(const Key('chat_model_config_ok')));
    await tester.pumpAndSettle();

    expect(result?.maxTokens, 512);
    expect(result?.accelerator, ChatAccelerator.cpu);
    expect(result?.systemPrompt, 'Reply in one sentence.');
  });

  testWidgets('cancel discards draft edits', (tester) async {
    await _setPhoneSurface(tester);
    ChatModelConfig? result = ChatModelConfig.defaults;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showChatModelConfigDialog(
                    context: context,
                    initial: ChatModelConfig.defaults,
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CPU'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat_model_config_cancel')));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
