import 'package:equatable/equatable.dart';

/// CPU vs GPU preference for on-device chat generation.
enum ChatAccelerator { cpu, gpu }

/// Per-conversation sampling and prompt overrides for the chat screen.
class ChatModelConfig extends Equatable {
  const ChatModelConfig({
    required this.maxTokens,
    required this.topK,
    required this.topP,
    required this.temperature,
    required this.accelerator,
    required this.systemPrompt,
  });

  static const int minMaxTokens = 64;
  static const int maxMaxTokens = 8192;
  static const int minTopK = 1;
  static const int maxTopK = 128;
  static const double minTopP = 0;
  static const double maxTopP = 1;
  static const double minTemperature = 0;
  static const double maxTemperature = 2;

  /// Defaults match the on-device Gemma gallery config the chat UI copies.
  static const ChatModelConfig defaults = ChatModelConfig(
    maxTokens: 4000,
    topK: 1,
    topP: 0.95,
    temperature: 1,
    accelerator: ChatAccelerator.gpu,
    systemPrompt: '',
  );

  final int maxTokens;
  final int topK;
  final double topP;
  final double temperature;
  final ChatAccelerator accelerator;
  final String systemPrompt;

  bool get preferGpu => accelerator == ChatAccelerator.gpu;

  ChatModelConfig copyWith({
    int? maxTokens,
    int? topK,
    double? topP,
    double? temperature,
    ChatAccelerator? accelerator,
    String? systemPrompt,
  }) {
    return ChatModelConfig(
      maxTokens: maxTokens ?? this.maxTokens,
      topK: topK ?? this.topK,
      topP: topP ?? this.topP,
      temperature: temperature ?? this.temperature,
      accelerator: accelerator ?? this.accelerator,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    ).normalized();
  }

  ChatModelConfig normalized() {
    return ChatModelConfig(
      maxTokens: maxTokens.clamp(minMaxTokens, maxMaxTokens).toInt(),
      topK: topK.clamp(minTopK, maxTopK).toInt(),
      topP: topP.clamp(minTopP, maxTopP).toDouble(),
      temperature: temperature.clamp(minTemperature, maxTemperature).toDouble(),
      accelerator: accelerator,
      systemPrompt: systemPrompt,
    );
  }

  /// Prepends a user-authored system prompt without replacing assembled context.
  String mergeSystemPrompt(String assembled) {
    final custom = systemPrompt.trim();
    final existing = assembled.trim();
    if (custom.isEmpty) return assembled;
    if (existing.isEmpty) return custom;
    return '$custom\n\n$assembled';
  }

  @override
  List<Object?> get props => [
    maxTokens,
    topK,
    topP,
    temperature,
    accelerator,
    systemPrompt,
  ];
}
