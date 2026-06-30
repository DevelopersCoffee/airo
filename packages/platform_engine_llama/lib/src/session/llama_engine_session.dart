import 'package:platform_engine_sdk/platform_engine_sdk.dart';

class LlamaEngineSession implements EngineSession {
  @override
  Future<void> initialize() async {
    // Native runtime init goes here
  }

  @override
  Stream<GenerationChunk> generate(GenerationRequest request) async* {
    // FFI bridge generation simulation
    yield const GenerationChunk(text: 'Mock generation from llama', isFinished: true);
  }

  @override
  Future<EmbeddingResult> embed(EmbeddingRequest request) async {
    // Mock FFI
    return const EmbeddingResult(embeddings: [[0.1, 0.2, 0.3]]);
  }

  @override
  Future<VisionResult> analyzeImage(VisionRequest request) async {
    throw const CapabilityException('Vision not supported on this llama.cpp build');
  }

  @override
  Future<AudioResult> transcribe(AudioRequest request) async {
    throw const CapabilityException('Audio not supported on llama.cpp');
  }

  @override
  Future<void> unload() async {
    // Native runtime dispose goes here
  }
}
