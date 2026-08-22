import 'package:meta/meta.dart';

@immutable
class AddonPrompt {
  const AddonPrompt({
    required this.systemInstruction,
    required this.userPrompt,
    this.metadata = const {},
  });

  final String systemInstruction;
  final String userPrompt;
  final Map<String, String> metadata;

  bool get isEmpty => systemInstruction.isEmpty && userPrompt.isEmpty;
}
