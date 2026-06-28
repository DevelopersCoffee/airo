import 'package:core_ai/core_ai.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo.gemini_nano');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('GeminiNanoClient.warmup', () {
    test(
      'invokes the native warmup method when the model is available and memory allows loading',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'isAvailable' => true,
            'warmup' => true,
            _ => fail('Unexpected method call: ${call.method}'),
          };
        });

        final client = GeminiNanoClient(
          memoryBudgetManager: _FakeMemoryBudgetManager(_safeMemoryCheck),
        );

        final warmed = await client.warmup();

        expect(warmed, isTrue);
        expect(calls.map((call) => call.method), ['isAvailable', 'warmup']);
      },
    );

    test(
      'returns false without invoking native warmup when the device is unavailable',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'isAvailable' => false,
            'warmup' => fail('warmup should not run on unsupported devices'),
            _ => fail('Unexpected method call: ${call.method}'),
          };
        });

        final client = GeminiNanoClient(
          memoryBudgetManager: _FakeMemoryBudgetManager(_safeMemoryCheck),
        );

        final warmed = await client.warmup();

        expect(warmed, isFalse);
        expect(calls.map((call) => call.method), ['isAvailable']);
      },
    );

    test(
      'returns false without invoking native warmup when memory is blocked',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'isAvailable' => true,
            'warmup' => fail('warmup should not run when memory is blocked'),
            _ => fail('Unexpected method call: ${call.method}'),
          };
        });

        final client = GeminiNanoClient(
          memoryBudgetManager: _FakeMemoryBudgetManager(_blockedMemoryCheck),
        );

        final warmed = await client.warmup();

        expect(warmed, isFalse);
        expect(calls.map((call) => call.method), ['isAvailable']);
      },
    );

    test(
      'returns false instead of throwing when the platform warmup fails',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'isAvailable' => true,
            'warmup' => throw PlatformException(
              code: 'WARMUP_FAILED',
              message: 'synthetic warmup failure',
            ),
            _ => fail('Unexpected method call: ${call.method}'),
          };
        });

        final client = GeminiNanoClient(
          memoryBudgetManager: _FakeMemoryBudgetManager(_safeMemoryCheck),
        );

        final warmed = await client.warmup();

        expect(warmed, isFalse);
      },
    );
  });
}

class _FakeMemoryBudgetManager implements MemoryBudgetManager {
  _FakeMemoryBudgetManager(this._result);

  final MemoryCheckResult _result;

  @override
  Future<MemoryCheckResult> checkModelFile({
    required int fileSizeBytes,
    required ModelType type,
    bool forceRefresh = false,
  }) async => _result;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _safeMemoryInfo = MemoryInfo(
  totalBytes: 12 * 1024 * 1024 * 1024,
  availableBytes: 8 * 1024 * 1024 * 1024,
);

final _safeMemoryCheck = MemoryCheckResult(
  severity: MemorySeverity.safe,
  memoryInfo: _safeMemoryInfo,
  estimatedUsageBytes: GeminiNanoClient.estimatedModelSizeBytes,
  budgetBytes:
      (12 * 1024 * 1024 * 1024 * MemoryBudgetManager.memoryBudgetPercent)
          .round(),
  modelType: ModelType.text,
);

const _blockedMemoryInfo = MemoryInfo(
  totalBytes: 4 * 1024 * 1024 * 1024,
  availableBytes: 512 * 1024 * 1024,
);

final _blockedMemoryCheck = MemoryCheckResult(
  severity: MemorySeverity.blocked,
  memoryInfo: _blockedMemoryInfo,
  estimatedUsageBytes: GeminiNanoClient.estimatedModelSizeBytes,
  budgetBytes:
      (4 * 1024 * 1024 * 1024 * MemoryBudgetManager.memoryBudgetPercent)
          .round(),
  modelType: ModelType.text,
);
