import 'package:platform_engine_sdk/src/models/requests.dart';
import 'package:platform_engine_sdk/src/models/results.dart';

abstract interface class EngineSession {
  Future<void> initialize();
  Stream<GenerationChunk> generate(GenerationRequest request);
  Future<EmbeddingResult> embed(EmbeddingRequest request);
  Future<VisionResult> analyzeImage(VisionRequest request);
  Future<AudioResult> transcribe(AudioRequest request);
  Future<void> unload();
}
