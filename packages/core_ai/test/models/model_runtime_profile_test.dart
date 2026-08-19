import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop GGUF profile excludes Gallery LiteRT packages', () {
    final models = ModelCatalog.forProfile(ModelRuntimeProfile.desktopGguf);

    expect(
      models.any((model) => model.id == 'gemma-4-e2b-it-litertlm'),
      isFalse,
    );
    expect(
      models.any(
        (model) => model.effectiveRuntime == InferenceRuntime.litertLm,
      ),
      isFalse,
    );
    expect(models.any((model) => model.id == 'qwen2-1.5b-q4'), isTrue);
  });

  test('Android on-device profile keeps the full bundled catalog', () {
    final models = ModelCatalog.forProfile(ModelRuntimeProfile.androidOnDevice);

    expect(models, ModelCatalog.bundledModels);
    expect(
      models.any((model) => model.id == 'gemma-4-e2b-it-litertlm'),
      isTrue,
    );
  });

  test('resolve picks desktop GGUF when the host is not Android', () {
    expect(
      ModelRuntimeProfile.resolve(isAndroidHost: false),
      ModelRuntimeProfile.desktopGguf,
    );
    expect(
      ModelRuntimeProfile.resolve(isAndroidHost: true),
      ModelRuntimeProfile.androidOnDevice,
    );
  });
}
