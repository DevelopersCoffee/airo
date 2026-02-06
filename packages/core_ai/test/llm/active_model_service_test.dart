import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ActiveModelService service;

  const testConfig = GGUFModelConfig(
    modelPath: '/path/to/model.gguf',
    modelName: 'Test Model',
    contextSize: 2048,
    batchSize: 512,
  );

  setUp(() {
    ActiveModelService.resetInstance();
    service = ActiveModelService.forTesting();
  });

  tearDown(() async {
    await service.dispose();
    ActiveModelService.resetInstance();
  });

  group('ActiveModelService', () {
    test('singleton instance should return same instance', () {
      final instance1 = ActiveModelService.instance;
      final instance2 = ActiveModelService.instance;
      expect(identical(instance1, instance2), true);
    });

    test('forTesting should create separate instance', () {
      final testInstance = ActiveModelService.forTesting();
      expect(identical(testInstance, ActiveModelService.instance), false);
    });

    test('initial state should have no active model', () {
      expect(service.activeModel, isNull);
      expect(service.hasActiveModel, false);
      expect(service.isLoading, false);
    });

    test('loadModel should load model successfully', () async {
      final result = await service.loadModel(testConfig);

      expect(result, isA<Ok<ActiveModelInfo>>());
      expect(service.hasActiveModel, true);
      expect(service.activeModel!.config.modelName, 'Test Model');
      expect(service.activeModel!.state, ActiveModelState.ready);
    });

    test('loadModel should call onProgress callback', () async {
      final progressUpdates = <double>[];
      final statusUpdates = <String>[];

      await service.loadModel(
        testConfig,
        onProgress: (progress, status) {
          progressUpdates.add(progress);
          statusUpdates.add(status);
        },
      );

      expect(progressUpdates, isNotEmpty);
      expect(progressUpdates.last, 1.0);
      expect(statusUpdates.last, 'Model ready');
    });

    test('loadModel should set loadedAt timestamp', () async {
      final before = DateTime.now();
      await service.loadModel(testConfig);
      final after = DateTime.now();

      expect(service.activeModel!.loadedAt, isNotNull);
      expect(
        service.activeModel!.loadedAt!.isAfter(
          before.subtract(const Duration(seconds: 1)),
        ),
        true,
      );
      expect(
        service.activeModel!.loadedAt!.isBefore(
          after.add(const Duration(seconds: 1)),
        ),
        true,
      );
    });

    test('unloadModel should clear active model', () async {
      await service.loadModel(testConfig);
      expect(service.hasActiveModel, true);

      await service.unloadModel();
      expect(service.activeModel, isNull);
      expect(service.hasActiveModel, false);
    });

    test('unloadModel should do nothing when no model loaded', () async {
      expect(service.activeModel, isNull);
      await service.unloadModel();
      expect(service.activeModel, isNull);
    });

    test('switchModel should unload existing and load new model', () async {
      await service.loadModel(testConfig);
      expect(service.activeModel!.config.modelName, 'Test Model');

      const newConfig = GGUFModelConfig(
        modelPath: '/path/to/other.gguf',
        modelName: 'Other Model',
      );

      await service.switchModel(newConfig);
      expect(service.activeModel!.config.modelName, 'Other Model');
    });

    test('stateStream should emit state changes', () async {
      final states = <ActiveModelInfo?>[];
      final subscription = service.stateStream.listen(states.add);

      await service.loadModel(testConfig);
      await service.unloadModel();

      // Give stream time to process
      await Future.delayed(const Duration(milliseconds: 50));

      await subscription.cancel();

      // Should have: loading, ready, unloading, null
      expect(states.length, greaterThanOrEqualTo(3));
      // First state should be loading
      expect(states.first!.state, ActiveModelState.loading);
      // Last non-null should be unloading, then null
      expect(states.any((s) => s == null), true);
    });

    test('updateMetrics should update tokensPerSecond', () async {
      await service.loadModel(testConfig);

      service.updateMetrics(tokensPerSecond: 25.5);
      expect(service.activeModel!.tokensPerSecond, 25.5);
    });

    test('updateMetrics should do nothing when no model loaded', () {
      service.updateMetrics(tokensPerSecond: 25.5);
      expect(service.activeModel, isNull);
    });
  });

  group('ActiveModelInfo', () {
    test('isReady should return true when state is ready', () {
      const info = ActiveModelInfo(
        config: testConfig,
        state: ActiveModelState.ready,
      );
      expect(info.isReady, true);
      expect(info.isLoading, false);
    });

    test('isLoading should return true when state is loading', () {
      const info = ActiveModelInfo(
        config: testConfig,
        state: ActiveModelState.loading,
      );
      expect(info.isLoading, true);
      expect(info.isReady, false);
    });
  });

  group('ActiveModelState', () {
    test('should have all expected values', () {
      expect(ActiveModelState.values, contains(ActiveModelState.unloaded));
      expect(ActiveModelState.values, contains(ActiveModelState.loading));
      expect(ActiveModelState.values, contains(ActiveModelState.ready));
      expect(ActiveModelState.values, contains(ActiveModelState.error));
      expect(ActiveModelState.values, contains(ActiveModelState.unloading));
    });
  });
}
