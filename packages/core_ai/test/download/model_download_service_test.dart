import 'dart:async';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockModelStorageManager extends Mock implements ModelStorageManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ModelDownloadService downloadService;
  late MockModelStorageManager mockStorageManager;
  late List<MethodCall> methodCalls;
  late StreamController<dynamic> progressStreamController;

  const MethodChannel methodChannel = MethodChannel('com.airo.model_download');
  const EventChannel eventChannel = EventChannel('com.airo.model_download/progress');

  final modelA = OfflineModelInfo(
    id: 'model_a',
    name: 'Model A',
    family: ModelFamily.gemma,
    fileSizeBytes: 1000,
    downloadUrl: 'https://example.com/a.gguf',
  );

  final modelB = OfflineModelInfo(
    id: 'model_b',
    name: 'Model B',
    family: ModelFamily.gemma,
    fileSizeBytes: 2000,
    downloadUrl: 'https://example.com/b.gguf',
  );

  setUp(() {
    methodCalls = <MethodCall>[];
    progressStreamController = StreamController<dynamic>.broadcast();

    // Mock Method Channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      methodChannel,
      (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return true;
      },
    );

    // Mock Event Channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      MethodChannel(eventChannel.name),
      (MethodCall methodCall) async {
        if (methodCall.method == 'listen') {
          progressStreamController.stream.listen((event) {
            final message = const StandardMethodCodec().encodeSuccessEnvelope(event);
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
              eventChannel.name,
              message,
              (_) {},
            );
          });
        }
        return null;
      },
    );

    mockStorageManager = MockModelStorageManager();
    
    // Default mock behavior
    when(() => mockStorageManager.verifyModelIntegrity(modelA)).thenAnswer((_) async => false);
    when(() => mockStorageManager.verifyModelIntegrity(modelB)).thenAnswer((_) async => false);
    when(() => mockStorageManager.hasEnoughDiskSpace(any())).thenAnswer((_) async => true);
    when(() => mockStorageManager.getModelPath(modelA.id)).thenAnswer((_) async => '/mock/path/model_a.gguf');
    when(() => mockStorageManager.getModelPath(modelB.id)).thenAnswer((_) async => '/mock/path/model_b.gguf');

    downloadService = ModelDownloadService(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
      storageManager: mockStorageManager,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(eventChannel.name), null);
    await progressStreamController.close();
    await downloadService.dispose();
  });

  test('downloadModel starts native download if active is idle', () async {
    final stream = downloadService.downloadModel(modelA);
    final futureProgress = stream.first;

    // Simulate progress updates from native
    progressStreamController.add({
      'modelId': 'model_a',
      'status': 'downloading',
      'downloadedBytes': 500,
      'totalBytes': 1000,
      'speedBytesPerSecond': 50.0,
    });

    final progress = await futureProgress;
    expect(progress.modelId, 'model_a');
    expect(progress.downloadedBytes, 500);
    expect(progress.status, ModelDownloadStatus.downloading);
  });

  test('downloadModel queues subsequent downloads and processes sequentially', () async {
    final streamA = downloadService.downloadModel(modelA);
    final futureA = streamA.toList();

    final streamB = downloadService.downloadModel(modelB);
    final futureB = streamB.first;

    // Let the microtasks run to queue the downloads
    await Future.delayed(Duration.zero);

    final progressB = await futureB;
    expect(progressB.status, ModelDownloadStatus.pending);

    expect(methodCalls.map((c) => c.arguments['modelId']), ['model_a']);

    progressStreamController.add({
      'modelId': 'model_a',
      'status': 'completed',
      'downloadedBytes': 1000,
      'totalBytes': 1000,
    });

    await futureA;
    await Future.delayed(Duration.zero);

    expect(methodCalls.map((c) => c.arguments['modelId']), ['model_a', 'model_b']);
  });

  test('cancelDownload removes from queue directly', () async {
    downloadService.downloadModel(modelA);
    final streamB = downloadService.downloadModel(modelB);

    final futureB = streamB.toList();

    // Let the microtasks run to queue the downloads
    await Future.delayed(Duration.zero);

    await downloadService.cancelDownload('model_b');

    final list = await futureB;
    expect(list.map((e) => e.status), contains(ModelDownloadStatus.cancelled));
  });

  test('cancelDownload invokes native cancel for active model', () async {
    downloadService.downloadModel(modelA);

    // Let the microtasks run to start the download
    await Future.delayed(Duration.zero);

    await downloadService.cancelDownload('model_a');

    expect(methodCalls.last.method, 'cancelDownload');
    expect(methodCalls.last.arguments['modelId'], 'model_a');
  });

  test('insufficient space fails download immediately', () async {
    when(() => mockStorageManager.hasEnoughDiskSpace(any())).thenAnswer((_) async => false);

    final stream = downloadService.downloadModel(modelA);
    final progress = await stream.first;

    expect(progress.status, ModelDownloadStatus.failed);
    expect(progress.error, contains('Insufficient disk space'));
    expect(methodCalls.isEmpty, isTrue);
  });
}
