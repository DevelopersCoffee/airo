import 'package:platform_engine_sdk/platform_engine_sdk.dart';

class RuntimeSelection {

  const RuntimeSelection({
    required this.provider,
    required this.confidence,
    this.reasons = const [],
    this.rejectedRuntimes = const [],
  });
  final EngineProvider provider;
  final double confidence;
  final List<String> reasons;
  final List<String> rejectedRuntimes;
}
