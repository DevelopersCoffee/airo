import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const smallModel = OfflineModelInfo(
    id: 'small-1b',
    name: 'Small 1B',
    family: ModelFamily.gemma,
    fileSizeBytes: 700000000,
    parameterCount: 900000000,
    filePath: '/models/small-1b.gguf',
  );

  const mediumModel = OfflineModelInfo(
    id: 'medium-3b',
    name: 'Medium 3B',
    family: ModelFamily.qwen,
    fileSizeBytes: 1800000000,
    parameterCount: 2800000000,
    filePath: '/models/medium-3b.gguf',
  );

  LlmDeviceSignals signalsForTier(LlmDeviceTier tier) => switch (tier) {
    LlmDeviceTier.none => const LlmDeviceSignals(
        totalRamMb: 1024,
        availableStorageMb: 4096,
      ),
    LlmDeviceTier.small => const LlmDeviceSignals(
        totalRamMb: 3200,
        availableStorageMb: 4096,
        chipsetClass: LlmChipsetClass.flagship,
      ),
    LlmDeviceTier.medium => const LlmDeviceSignals(
        totalRamMb: 5200,
        availableStorageMb: 4096,
        chipsetClass: LlmChipsetClass.flagship,
      ),
    LlmDeviceTier.large => const LlmDeviceSignals(
        totalRamMb: 8192,
        availableStorageMb: 8192,
        chipsetClass: LlmChipsetClass.flagship,
      ),
  };

  test('device tier none, no consent -> unavailable, not a silent cloud call',
      () async {
    final router = LlmLocalCloudRouter(
      signalsProbe: FakeLlmDeviceSignalsProbe(signalsForTier(LlmDeviceTier.none)),
    );

    final decision = await router.route(installedModels: const []);

    expect(decision.target, LlmRoutingTarget.unavailable);
    expect(decision.tier, LlmDeviceTier.none);
    expect(decision.reasons, contains(LlmRoutingReasonCode.deviceTierNone));
    expect(
      decision.reasons,
      contains(LlmRoutingReasonCode.cloudConsentMissing),
    );
  });

  test('device tier none, consent granted -> cloud fallback', () async {
    final router = LlmLocalCloudRouter(
      signalsProbe: FakeLlmDeviceSignalsProbe(signalsForTier(LlmDeviceTier.none)),
      consentGate: InMemoryLlmCloudConsentGate(granted: true),
    );

    final decision = await router.route(installedModels: const []);

    expect(decision.target, LlmRoutingTarget.cloud);
    expect(
      decision.reasons,
      contains(LlmRoutingReasonCode.cloudConsentGranted),
    );
  });

  test('small tier with an installed small model routes local', () async {
    final router = LlmLocalCloudRouter(
      signalsProbe:
          FakeLlmDeviceSignalsProbe(signalsForTier(LlmDeviceTier.small)),
    );

    final decision = await router.route(
      installedModels: const [smallModel],
      taskId: 'chat',
    );

    expect(decision.target, LlmRoutingTarget.local);
    expect(decision.tier, LlmDeviceTier.small);
    expect(decision.taskId, 'chat');
  });

  test(
    'small tier with only a medium model installed cannot serve locally',
    () async {
      final router = LlmLocalCloudRouter(
        signalsProbe:
            FakeLlmDeviceSignalsProbe(signalsForTier(LlmDeviceTier.small)),
      );

      final decision = await router.route(installedModels: const [mediumModel]);

      expect(decision.target, LlmRoutingTarget.unavailable);
      expect(
        decision.reasons,
        contains(LlmRoutingReasonCode.noLocalModelInstalledForTier),
      );
    },
  );

  test('complex query on a medium-tier device escalates to cloud when '
      'consented', () async {
    final router = LlmLocalCloudRouter(
      signalsProbe:
          FakeLlmDeviceSignalsProbe(signalsForTier(LlmDeviceTier.medium)),
      consentGate: InMemoryLlmCloudConsentGate(granted: true),
    );

    final decision = await router.route(
      installedModels: const [mediumModel],
      isComplexQuery: true,
    );

    expect(decision.target, LlmRoutingTarget.cloud);
    expect(
      decision.reasons,
      contains(LlmRoutingReasonCode.complexQueryEscalatedToCloud),
    );
  });

  test('complex query on a medium-tier device with no consent stays local '
      'instead of failing', () async {
    final router = LlmLocalCloudRouter(
      signalsProbe:
          FakeLlmDeviceSignalsProbe(signalsForTier(LlmDeviceTier.medium)),
    );

    final decision = await router.route(
      installedModels: const [mediumModel],
      isComplexQuery: true,
    );

    expect(decision.target, LlmRoutingTarget.local);
    expect(
      decision.reasons,
      contains(LlmRoutingReasonCode.complexQueryKeptLocalNoConsent),
    );
  });

  test('a long prompt is treated as a complex query via the threshold, not '
      'just the explicit flag', () async {
    final router = LlmLocalCloudRouter(
      signalsProbe:
          FakeLlmDeviceSignalsProbe(signalsForTier(LlmDeviceTier.medium)),
      consentGate: InMemoryLlmCloudConsentGate(granted: true),
      complexQueryPromptThreshold: 100,
    );

    final decision = await router.route(
      installedModels: const [mediumModel],
      promptLength: 5000,
    );

    expect(decision.target, LlmRoutingTarget.cloud);
    expect(decision.promptLength, 5000);
  });

  test('large-tier devices never escalate on complexity alone', () async {
    const largeModel = OfflineModelInfo(
      id: 'large-7b',
      name: 'Large 7B',
      family: ModelFamily.mistral,
      fileSizeBytes: 4200000000,
      parameterCount: 6800000000,
      filePath: '/models/large-7b.gguf',
    );
    final router = LlmLocalCloudRouter(
      signalsProbe:
          FakeLlmDeviceSignalsProbe(signalsForTier(LlmDeviceTier.large)),
      consentGate: InMemoryLlmCloudConsentGate(granted: true),
    );

    final decision = await router.route(
      installedModels: const [largeModel],
      isComplexQuery: true,
    );

    expect(decision.target, LlmRoutingTarget.local);
  });

  test('every decision is recorded to the inspectable log', () async {
    final router = LlmLocalCloudRouter(
      signalsProbe:
          FakeLlmDeviceSignalsProbe(signalsForTier(LlmDeviceTier.small)),
    );

    await router.route(installedModels: const [smallModel], taskId: 'first');
    await router.route(installedModels: const [smallModel], taskId: 'second');

    final recent = router.log.recent();
    expect(recent, hasLength(2));
    // Newest first.
    expect(recent.first.taskId, 'second');
    expect(recent.last.taskId, 'first');
  });

  test('log emits decisions on its stream for a live inspector', () async {
    final router = LlmLocalCloudRouter(
      signalsProbe:
          FakeLlmDeviceSignalsProbe(signalsForTier(LlmDeviceTier.small)),
    );

    final emitted = <LlmRoutingDecision>[];
    final subscription = router.log.onDecision.listen(emitted.add);

    await router.route(installedModels: const [smallModel]);
    await Future<void>.delayed(Duration.zero);

    expect(emitted, hasLength(1));
    await subscription.cancel();
  });
}
