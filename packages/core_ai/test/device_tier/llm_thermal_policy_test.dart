import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = LlmThermalPolicy();

  test('nominal pressure, job not paused -> proceed', () {
    expect(
      policy.decide(
        pressure: LlmThermalPressure.nominal,
        jobCurrentlyPaused: false,
      ),
      LlmBatchJobAction.proceed,
    );
  });

  test('fair pressure, job not paused -> proceed (no throttle state exists)',
      () {
    expect(
      policy.decide(
        pressure: LlmThermalPressure.fair,
        jobCurrentlyPaused: false,
      ),
      LlmBatchJobAction.proceed,
    );
  });

  test('serious pressure -> pause, even if not yet paused', () {
    expect(
      policy.decide(
        pressure: LlmThermalPressure.serious,
        jobCurrentlyPaused: false,
      ),
      LlmBatchJobAction.pause,
    );
  });

  test('critical pressure -> pause', () {
    expect(
      policy.decide(
        pressure: LlmThermalPressure.critical,
        jobCurrentlyPaused: false,
      ),
      LlmBatchJobAction.pause,
    );
  });

  test('pressure eases from serious to nominal while paused -> resume', () {
    expect(
      policy.decide(
        pressure: LlmThermalPressure.nominal,
        jobCurrentlyPaused: true,
      ),
      LlmBatchJobAction.resume,
    );
  });

  test('still under pressure while already paused -> stays paused, not a '
      'lesser throttled state', () {
    expect(
      policy.decide(
        pressure: LlmThermalPressure.serious,
        jobCurrentlyPaused: true,
      ),
      LlmBatchJobAction.pause,
    );
  });
}
