import 'package:platform_delegates/platform_delegates.dart';
import 'package:platform_engine_sdk/platform_engine_sdk.dart';

class LitertEngineSession implements EngineSession {

  const LitertEngineSession({required this.delegateSelection});
  final DelegateSelection delegateSelection;

  @override
  Future<void> initialize() async {
    // Native LiteRT init + delegate attachment goes here
  }

  @override
  Stream<GenerationChunk> generate(GenerationRequest request) async* {
    yield const GenerationChunk(text: 'Mock generation from LiteRT', isFinished: true);
  }

  @override
  Future<EmbeddingResult> embed(EmbeddingRequest request) async {
    throw const CapabilityException('Embeddings not supported on LiteRT');
  }

  @override
  Future<VisionResult> analyzeImage(VisionRequest request) async {
    return const VisionResult(description: 'LiteRT vision analysis');
  }

  @override
  Future<AudioResult> transcribe(AudioRequest request) async {
    throw const CapabilityException('Audio not supported on LiteRT');
  }

  @override
  Future<void> unload() async {
    // Native dispose
  }
}
