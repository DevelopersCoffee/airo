import 'package:feature_mind/src/runtime/fixture/fixture_mind_runtime.dart';
import 'package:feature_mind/src/runtime/models/model_models.dart';
import 'package:feature_mind/src/runtime/ports/model_port.dart';
import 'package:feature_mind/src/runtime/scribe_mind_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses injected ModelPort rather than fixture models', () async {
    final injected = _FakeModelPort();
    final runtime = ScribeMindRuntime(
      log: FixtureMindRuntime().log,
      models: injected,
    );

    expect(identical(runtime.models, injected), isTrue);
    await expectLater(runtime.models.all(), completion(injected.mindModels));
  });

  test('falls back to fixture models when none are injected', () async {
    final runtime = ScribeMindRuntime(log: FixtureMindRuntime().log);
    final models = await runtime.models.all();
    final fixture = await FixtureMindRuntime().models.all();
    expect(models, fixture);
  });
}

class _FakeModelPort implements ModelPort {
  final mindModels = const [
    MindModel(
      id: 'injected',
      name: 'Injected',
      sizeBytes: 1,
      residency: ModelResidency.resident,
    ),
  ];

  @override
  Future<List<MindModel>> all() async => mindModels;

  @override
  Future<({int budgetBytes, int usedBytes})> storage() async =>
      (usedBytes: 0, budgetBytes: 1);

  @override
  Future<void> load(String modelId) async {}

  @override
  Future<void> unload(String modelId) async {}

  @override
  Stream<({int received, int total})> download(String modelId) =>
      const Stream.empty();

  @override
  Future<ModelBench> benchmark(String modelId) async =>
      throw StateError('not used');

  @override
  Stream<ThermalState> thermal() => const Stream.empty();
}
