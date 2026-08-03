import '../models/model_models.dart';

/// On-device models: what is loaded, what is held, what could be fetched.
abstract interface class ModelPort {
  Future<List<MindModel>> all();

  /// Bytes used and bytes available for models on this device.
  Future<({int usedBytes, int budgetBytes})> storage();

  Future<void> load(String modelId);

  /// Fails rather than silently breaking a capability that holds the model
  /// resident. The error names that capability.
  Future<void> unload(String modelId);

  /// Emits bytes downloaded of total. Pauses on metered connections; the
  /// stream stalls rather than erroring, and resumes when unmetered.
  Stream<({int received, int total})> download(String modelId);

  /// Measures on this hardware. Never returns a spec-sheet figure.
  Future<ModelBench> benchmark(String modelId);

  /// Emits on every thermal transition, which is the trigger to re-benchmark.
  Stream<ThermalState> thermal();
}
