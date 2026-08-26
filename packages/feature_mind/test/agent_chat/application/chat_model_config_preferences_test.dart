import 'package:feature_mind/src/agent_chat/application/chat_model_config_preferences.dart';
import 'package:feature_mind/src/agent_chat/domain/models/chat_model_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads persisted sampling values', () async {
    SharedPreferences.setMockInitialValues({
      chatModelConfigMaxTokensKey: 1024,
      chatModelConfigTopKKey: 20,
      chatModelConfigTopPKey: 0.8,
      chatModelConfigTemperatureKey: 0.4,
      chatModelConfigAcceleratorKey: ChatAccelerator.cpu.name,
      chatModelConfigSystemPromptKey: 'Be terse.',
    });

    final notifier = ChatModelConfigNotifier();
    await Future<void>.delayed(Duration.zero);

    expect(
      notifier.state,
      const ChatModelConfig(
        maxTokens: 1024,
        topK: 20,
        topP: 0.8,
        temperature: 0.4,
        accelerator: ChatAccelerator.cpu,
        systemPrompt: 'Be terse.',
      ),
    );
  });

  test('save writes clamped values to preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = ChatModelConfigNotifier();
    await Future<void>.delayed(Duration.zero);

    await notifier.save(
      const ChatModelConfig(
        maxTokens: 99999,
        topK: 8,
        topP: 0.5,
        temperature: 0.2,
        accelerator: ChatAccelerator.cpu,
        systemPrompt: 'Stay local.',
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(chatModelConfigMaxTokensKey), 8192);
    expect(prefs.getInt(chatModelConfigTopKKey), 8);
    expect(prefs.getString(chatModelConfigAcceleratorKey), 'cpu');
    expect(notifier.state.maxTokens, 8192);
    expect(notifier.state.systemPrompt, 'Stay local.');
  });
}
