import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelCatalog web runtime support', () {
    test('Gemma-4-E2B is flagged web-capable with a .task asset URL', () {
      final model = ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'gemma-4-e2b-it-litertlm',
      );

      expect(model.supportsWebRuntime, isTrue);
      expect(model.webAssetUrl, isNotNull);
      expect(model.webAssetUrl, endsWith('.task'));
    });

    test('Gemma-4-E4B is flagged web-capable with a .task asset URL', () {
      final model = ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'gemma-4-e4b-it-litertlm',
      );

      expect(model.supportsWebRuntime, isTrue);
      expect(model.webAssetUrl, isNotNull);
      expect(model.webAssetUrl, endsWith('.task'));
    });

    test('Qwen2.5-1.5B is flagged web-capable with a .task asset URL', () {
      final model = ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'qwen2.5-1.5b-it-litert',
      );

      expect(model.supportsWebRuntime, isTrue);
      expect(model.webAssetUrl, isNotNull);
      expect(model.webAssetUrl, endsWith('.task'));
    });

    test('non-Gemma models default to web-unsupported', () {
      final model = ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'mistral-7b-q4',
      );

      expect(model.supportsWebRuntime, isFalse);
      expect(model.webAssetUrl, isNull);
    });

    test('byWebRuntimeSupport returns only web-capable models', () {
      final webModels = ModelCatalog.webRuntimeSupported;

      expect(webModels, isNotEmpty);
      expect(webModels.every((m) => m.supportsWebRuntime), isTrue);
    });
  });
}
