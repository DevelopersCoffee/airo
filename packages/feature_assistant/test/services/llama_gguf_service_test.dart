import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:llama_flutter_android/src/llama_api.dart' as llama_api;

import 'package:feature_assistant/src/services/llama_gguf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    _clearLlamaHostHandlers();
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

  test(
    'loads GGUF models through the Android adapter with a clamped context',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <String, Object?>{};
      _mockLlamaHost(
        onLoadModel: (config) {
          calls['modelPath'] = config.modelPath;
          calls['threads'] = config.nThreads;
          calls['contextSize'] = config.contextSize;
          calls['gpuLayers'] = config.nGpuLayers;
        },
      );
      final controller = LlamaController(
        binaryMessenger:
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
      );
      final service = LlamaGgufService(nativeController: controller);
      const model = OfflineModelInfo(
        id: 'gguf-android',
        name: 'GGUF Android',
        family: ModelFamily.llama,
        fileSizeBytes: 1024,
        filePath: '/models/release.gguf',
        contextLength: 16384,
      );

      await expectLater(service.isAvailable(), completion(isTrue));
      await expectLater(
        service.loadModel(model, contextSize: 32768, threads: 6),
        completion(isTrue),
      );
      await expectLater(service.unload(), completes);

      expect(calls['modelPath'], '/models/release.gguf');
      expect(calls['threads'], 6);
      expect(calls['contextSize'], 8192);
      expect(calls['gpuLayers'], 16);
    },
  );

  test('streams generated GGUF tokens and disposes native resources', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var disposed = false;
    _mockLlamaHost(onDispose: () => disposed = true);
    final controller = LlamaController(
      binaryMessenger:
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
    );
    final service = LlamaGgufService(nativeController: controller);
    const model = OfflineModelInfo(
      id: 'gguf-stream',
      name: 'GGUF stream',
      family: ModelFamily.llama,
      fileSizeBytes: 1024,
      filePath: '/models/stream.gguf',
    );

    await expectLater(service.loadModel(model), completion(isTrue));
    final expectation = expectLater(
      service.generate(prompt: 'say hello'),
      emitsInOrder(<Object?>['hello', ' gguf', emitsDone]),
    );
    await Future<void>.delayed(Duration.zero);
    controller.onToken('hello');
    controller.onToken(' gguf');
    controller.onDone();
    await expectation;
    await expectLater(service.unload(), completes);

    expect(disposed, isTrue);
  });
}

typedef _ModelConfigSpy = void Function(ModelConfig config);
typedef _GenerateRequestSpy = void Function(GenerateRequest request);

void _mockLlamaHost({
  _ModelConfigSpy? onLoadModel,
  _GenerateRequestSpy? onGenerate,
  VoidCallback? onDispose,
}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockDecodedMessageHandler(_hostChannel('detectGpu'), (_) async {
    return <Object?>[
      GpuInfo(
        vulkanSupported: true,
        gpuName: 'Test GPU',
        vulkanApiVersion: 4206592,
        deviceLocalMemoryBytes: 8 * 1024 * 1024 * 1024,
        freeRamBytes: 5 * 1024 * 1024 * 1024,
        recommendedGpuLayers: 16,
      ),
    ];
  });
  messenger.setMockDecodedMessageHandler(_hostChannel('isModelLoaded'), (
    _,
  ) async {
    return <Object?>[false];
  });
  messenger.setMockDecodedMessageHandler(_hostChannel('loadModel'), (
    message,
  ) async {
    final args = (message as List<Object?>?)!;
    onLoadModel?.call(args.single! as ModelConfig);
    return <Object?>[];
  });
  messenger.setMockDecodedMessageHandler(_hostChannel('generate'), (
    message,
  ) async {
    final args = (message as List<Object?>?)!;
    onGenerate?.call(args.single! as GenerateRequest);
    return <Object?>[];
  });
  messenger.setMockDecodedMessageHandler(_hostChannel('stop'), (_) async {
    return <Object?>[];
  });
  messenger.setMockDecodedMessageHandler(_hostChannel('dispose'), (_) async {
    onDispose?.call();
    return <Object?>[];
  });
  // Keep the analyzer aware that the test messenger is intentionally selected.
  expect(messenger, isNotNull);
}

void _clearLlamaHostHandlers() {
  for (final method in <String>[
    'detectGpu',
    'isModelLoaded',
    'loadModel',
    'generate',
    'stop',
    'dispose',
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler(_hostChannel(method), null);
  }
}

BasicMessageChannel<Object?> _hostChannel(String method) {
  return BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.llama_flutter_android.LlamaHostApi.$method',
    llama_api.LlamaHostApi.pigeonChannelCodec,
    binaryMessenger:
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
  );
}
