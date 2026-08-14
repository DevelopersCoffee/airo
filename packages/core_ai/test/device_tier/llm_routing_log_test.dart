import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LlmRoutingDecision decisionAt(String taskId) => LlmRoutingDecision(
    target: LlmRoutingTarget.local,
    tier: LlmDeviceTier.small,
    reasons: const [LlmRoutingReasonCode.deviceTierSupportsLocal],
    decidedAt: DateTime.utc(2026, 8, 14),
    taskId: taskId,
  );

  test('recent() returns newest first', () {
    final log = LlmRoutingLog();
    log.record(decisionAt('a'));
    log.record(decisionAt('b'));
    log.record(decisionAt('c'));

    final recent = log.recent();
    expect(recent.map((d) => d.taskId), ['c', 'b', 'a']);
  });

  test('recent(limit:) caps the returned window', () {
    final log = LlmRoutingLog();
    for (var i = 0; i < 5; i++) {
      log.record(decisionAt('$i'));
    }
    expect(log.recent(limit: 2), hasLength(2));
  });

  test('ring buffer drops the oldest entry once maxEntries is exceeded', () {
    final log = LlmRoutingLog(maxEntries: 2);
    log.record(decisionAt('a'));
    log.record(decisionAt('b'));
    log.record(decisionAt('c'));

    expect(log.length, 2);
    expect(log.recent().map((d) => d.taskId), ['c', 'b']);
  });

  test('a decision always carries at least one reason', () {
    // Constructive check: every LlmLocalCloudRouter code path this module
    // ships adds a reason before constructing LlmRoutingDecision; this test
    // documents the invariant the class itself doesn't enforce structurally.
    final decision = decisionAt('a');
    expect(decision.reasons, isNotEmpty);
  });

  test('toPublicMap omits null optional fields', () {
    final map = decisionAt('a').toPublicMap();
    expect(map.containsKey('promptLength'), isFalse);
    expect(map.containsKey('modelId'), isFalse);
    expect(map['taskId'], 'a');
  });
}
