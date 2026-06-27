import 'package:airo_app/features/agent_chat/data/services/assistant_runtime_service.dart';
import 'package:airo_app/features/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssistantRuntimeService', () {
    test(
      'reports Gemini Nano unavailable instead of using canned fallback',
      () async {
        final service = AssistantRuntimeService(
          isGeminiNanoSupported: () async => false,
          initializeGeminiNano: () async => throw StateError('should not init'),
          generateGeminiNanoText: (_) async => 'fake fallback',
        );

        expect(
          () => service.generateText(
            selectedModelId: geminiNanoAssistantModelId,
            prompt: 'hello',
          ),
          throwsA(
            isA<AssistantRuntimeUnavailableException>().having(
              (error) => error.message,
              'message',
              geminiNanoUnavailableMessage,
            ),
          ),
        );
      },
    );

    test('routes LiteRT-LM text through the selected runtime', () async {
      final service = AssistantRuntimeService(
        generateLiteRtText: (prompt, {systemPrompt}) async {
          return '${systemPrompt ?? 'no-system'} :: $prompt';
        },
      );

      final text = await service.generateText(
        selectedModelId: litertGemmaAssistantModelId,
        systemPrompt: 'skill planner',
        prompt: 'pick a tool',
      );

      expect(text, 'skill planner :: pick a tool');
    });

    test('reports Gemini Cloud configuration errors explicitly', () async {
      final service = AssistantRuntimeService(
        initializeCloud: () async {},
        isCloudAvailable: () => false,
        generateCloudText: (_) async => 'should not run',
      );

      expect(
        () => service.generateText(
          selectedModelId: geminiCloudAssistantModelId,
          prompt: 'hello',
        ),
        throwsA(
          isA<AssistantRuntimeUnavailableException>().having(
            (error) => error.message,
            'message',
            geminiCloudUnavailableMessage,
          ),
        ),
      );
    });
  });
}
