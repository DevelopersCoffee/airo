import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/chat_model_config.dart';

const String chatModelConfigMaxTokensKey = 'chat_model_config.max_tokens';
const String chatModelConfigTopKKey = 'chat_model_config.top_k';
const String chatModelConfigTopPKey = 'chat_model_config.top_p';
const String chatModelConfigTemperatureKey = 'chat_model_config.temperature';
const String chatModelConfigAcceleratorKey = 'chat_model_config.accelerator';
const String chatModelConfigSystemPromptKey = 'chat_model_config.system_prompt';

final chatModelConfigProvider =
    StateNotifierProvider<ChatModelConfigNotifier, ChatModelConfig>((ref) {
      return ChatModelConfigNotifier();
    });

class ChatModelConfigNotifier extends StateNotifier<ChatModelConfig> {
  ChatModelConfigNotifier() : super(ChatModelConfig.defaults) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ChatModelConfig(
      maxTokens:
          prefs.getInt(chatModelConfigMaxTokensKey) ??
          ChatModelConfig.defaults.maxTokens,
      topK:
          prefs.getInt(chatModelConfigTopKKey) ?? ChatModelConfig.defaults.topK,
      topP:
          prefs.getDouble(chatModelConfigTopPKey) ??
          ChatModelConfig.defaults.topP,
      temperature:
          prefs.getDouble(chatModelConfigTemperatureKey) ??
          ChatModelConfig.defaults.temperature,
      accelerator: _acceleratorFromName(
        prefs.getString(chatModelConfigAcceleratorKey),
      ),
      systemPrompt:
          prefs.getString(chatModelConfigSystemPromptKey) ??
          ChatModelConfig.defaults.systemPrompt,
    ).normalized();
  }

  Future<void> save(ChatModelConfig config) async {
    final next = config.normalized();
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(chatModelConfigMaxTokensKey, next.maxTokens);
    await prefs.setInt(chatModelConfigTopKKey, next.topK);
    await prefs.setDouble(chatModelConfigTopPKey, next.topP);
    await prefs.setDouble(chatModelConfigTemperatureKey, next.temperature);
    await prefs.setString(chatModelConfigAcceleratorKey, next.accelerator.name);
    await prefs.setString(chatModelConfigSystemPromptKey, next.systemPrompt);
  }

  static ChatAccelerator _acceleratorFromName(String? raw) {
    return ChatAccelerator.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => ChatModelConfig.defaults.accelerator,
    );
  }
}
