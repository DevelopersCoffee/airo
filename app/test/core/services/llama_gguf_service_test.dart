import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

import 'package:airo_app/core/services/llama_gguf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'accepts an injected native controller without probing the platform',
    () {
      final controller = LlamaController(
        binaryMessenger:
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
      );

      final service = LlamaGgufService(nativeController: controller);

      expect(service.generate(prompt: 'hello'), emitsError(isA<StateError>()));
    },
  );

  test('reports unavailable and refuses model loading off Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final service = LlamaGgufService();
    final model = OfflineModelInfo(
      id: 'gguf-release-check',
      name: 'GGUF release check',
      family: ModelFamily.llama,
      fileSizeBytes: 1024,
      filePath: '/tmp/model.gguf',
    );

    expect(service.isPlatformSupported, isFalse);
    await expectLater(service.isAvailable(), completion(isFalse));
    await expectLater(service.loadModel(model), completion(isFalse));
    await expectLater(service.unload(), completes);
  });

  test(
    'rejects missing model paths before touching the native adapter',
    () async {
      final service = LlamaGgufService();
      const model = OfflineModelInfo(
        id: 'gguf-missing-path',
        name: 'GGUF missing path',
        family: ModelFamily.llama,
        fileSizeBytes: 1024,
        filePath: '   ',
      );

      await expectLater(service.loadModel(model), completion(isFalse));
      expect(service.generate(prompt: 'hello'), emitsError(isA<StateError>()));
      await expectLater(service.stop(), completes);
    },
  );
}
