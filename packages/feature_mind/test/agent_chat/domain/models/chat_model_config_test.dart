import 'package:feature_mind/src/agent_chat/domain/models/chat_model_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults match the gallery model-config screenshot', () {
    expect(ChatModelConfig.defaults.maxTokens, 4000);
    expect(ChatModelConfig.defaults.topK, 1);
    expect(ChatModelConfig.defaults.topP, 0.95);
    expect(ChatModelConfig.defaults.temperature, 1);
    expect(ChatModelConfig.defaults.accelerator, ChatAccelerator.gpu);
    expect(ChatModelConfig.defaults.systemPrompt, isEmpty);
    expect(ChatModelConfig.defaults.preferGpu, isTrue);
  });

  test('normalized clamps sampling fields to supported ranges', () {
    const raw = ChatModelConfig(
      maxTokens: 12,
      topK: 400,
      topP: 1.4,
      temperature: -0.2,
      accelerator: ChatAccelerator.cpu,
      systemPrompt: 'Stay brief.',
    );

    expect(
      raw.normalized(),
      const ChatModelConfig(
        maxTokens: ChatModelConfig.minMaxTokens,
        topK: ChatModelConfig.maxTopK,
        topP: ChatModelConfig.maxTopP,
        temperature: ChatModelConfig.minTemperature,
        accelerator: ChatAccelerator.cpu,
        systemPrompt: 'Stay brief.',
      ),
    );
  });

  test('mergeSystemPrompt prepends a custom override', () {
    const config = ChatModelConfig(
      maxTokens: 4000,
      topK: 1,
      topP: 0.95,
      temperature: 1,
      accelerator: ChatAccelerator.gpu,
      systemPrompt: 'Answer in Hindi.',
    );

    expect(
      config.mergeSystemPrompt('You are Airo.'),
      'Answer in Hindi.\n\nYou are Airo.',
    );
    expect(config.mergeSystemPrompt('  '), 'Answer in Hindi.');
    expect(
      ChatModelConfig.defaults.mergeSystemPrompt('You are Airo.'),
      'You are Airo.',
    );
  });
}
