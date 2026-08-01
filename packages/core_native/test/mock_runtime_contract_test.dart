import 'package:core_native/core_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MockRuntime configuration and observability types are public', () {
    final config = MockConfig(
      startupDelayMs: BigInt.from(100),
      firstTokenDelayMs: BigInt.from(20),
      tokenDelayMs: BigInt.from(20),
      tokenRate: 50,
      seed: BigInt.from(42),
      failure: RuntimeErrorCode.outOfMemory,
      failAfterTokens: 2,
      cancelAfterTokens: null,
    );
    const injection = FailureInjection(
      error: RuntimeErrorCode.timeout,
      afterTokens: 3,
      cancelAfterTokens: null,
    );

    expect(config.seed, BigInt.from(42));
    expect(config.failure, RuntimeErrorCode.outOfMemory);
    expect(injection.error, RuntimeErrorCode.timeout);
    expect(RuntimeHealthState.values, contains(RuntimeHealthState.recovering));
    expect(
      ExecutionTrace(entries: const []),
      ExecutionTrace(entries: const []),
    );
    expect(TelemetryStub(events: const []), TelemetryStub(events: const []));
  });
}
