import 'package:flutter_test/flutter_test.dart';
import 'package:feature_mind/src/governor/mind_resource_governor.dart';
import 'package:feature_mind/src/runtime/models/model_models.dart'
    show ThermalState, ModelResidency;

void main() {
  const governor = MindResourceGovernor();

  group('recording and STT are invariants', () {
    test('never disabled under any pressure', () {
      final decision = governor.decide(
        const MindGovernorSignals(
          thermal: MindThermalLevel.critical,
          batteryPercent: 3,
          availableMemoryMb: 100,
        ),
      );
      expect(decision.recordingEnabled, isTrue);
      expect(decision.sttEnabled, isTrue);
      // ...but intelligence is fully shed.
      expect(decision.fastIntelligenceEnabled, isFalse);
      expect(decision.deepIntelligenceEnabled, isFalse);
    });
  });

  group('thermal policy (spec §11)', () {
    test('normal keeps full intelligence', () {
      final d = governor.decide(const MindGovernorSignals());
      expect(d.isFullIntelligence, isTrue);
      expect(d.reasons, isEmpty);
    });

    test('warm reduces fast frequency but keeps deep', () {
      final d = governor.decide(
        const MindGovernorSignals(thermal: MindThermalLevel.warm),
      );
      expect(d.fastIntelligenceFrequency, MindIntelligenceFrequency.reduced);
      expect(d.deepIntelligenceEnabled, isTrue);
    });

    test('hot disables deep intelligence', () {
      final d = governor.decide(
        const MindGovernorSignals(thermal: MindThermalLevel.hot),
      );
      expect(d.deepIntelligenceEnabled, isFalse);
      expect(d.fastIntelligenceEnabled, isTrue);
    });

    test('critical is STT/capture only', () {
      final d = governor.decide(
        const MindGovernorSignals(thermal: MindThermalLevel.critical),
      );
      expect(d.fastIntelligenceFrequency, MindIntelligenceFrequency.off);
      expect(d.deepIntelligenceEnabled, isFalse);
    });
  });

  group('battery policy (spec §11)', () {
    test('below 20% discharging reduces intelligence and disables deep', () {
      final d = governor.decide(
        const MindGovernorSignals(batteryPercent: 15, charging: false),
      );
      expect(d.fastIntelligenceFrequency, MindIntelligenceFrequency.reduced);
      expect(d.deepIntelligenceEnabled, isFalse);
    });

    test('below 10% discharging is capture/STT priority', () {
      final d = governor.decide(
        const MindGovernorSignals(batteryPercent: 8, charging: false),
      );
      expect(d.fastIntelligenceFrequency, MindIntelligenceFrequency.off);
      expect(d.deepIntelligenceEnabled, isFalse);
    });

    test('low battery while charging does not constrain', () {
      final d = governor.decide(
        const MindGovernorSignals(batteryPercent: 5, charging: true),
      );
      expect(d.isFullIntelligence, isTrue);
    });

    test('unknown battery does not constrain', () {
      final d = governor.decide(const MindGovernorSignals());
      expect(d.isFullIntelligence, isTrue);
    });
  });

  group('memory headroom policy (spec §10)', () {
    test('ample headroom keeps full intelligence', () {
      final d = governor.decide(
        const MindGovernorSignals(availableMemoryMb: 8000),
      );
      expect(d.isFullIntelligence, isTrue);
    });

    test('headroom fits fast but not deep disables deep only', () {
      final d = governor.decide(
        const MindGovernorSignals(
          availableMemoryMb: 1500,
          deepModelEstimateMb: 2600,
          fastModelEstimateMb: 700,
          reserveMemoryMb: 512,
        ),
      );
      expect(d.deepIntelligenceEnabled, isFalse);
      expect(d.fastIntelligenceEnabled, isTrue);
    });

    test('headroom below fast estimate disables all intelligence', () {
      final d = governor.decide(
        const MindGovernorSignals(availableMemoryMb: 300),
      );
      expect(d.fastIntelligenceEnabled, isFalse);
      expect(d.deepIntelligenceEnabled, isFalse);
    });

    test('unknown memory does not restrict', () {
      final d = governor.decide(const MindGovernorSignals());
      expect(d.isFullIntelligence, isTrue);
    });
  });

  group('combination takes the most restrictive dimension', () {
    test(
      'warm thermal + ample memory keeps deep (thermal warm allows deep)',
      () {
        final d = governor.decide(
          const MindGovernorSignals(
            thermal: MindThermalLevel.warm,
            availableMemoryMb: 8000,
          ),
        );
        expect(d.fastIntelligenceFrequency, MindIntelligenceFrequency.reduced);
        expect(d.deepIntelligenceEnabled, isTrue);
      },
    );

    test('two distinct tightening steps are both recorded in reasons', () {
      // Warm reduces frequency (deep still on); battery < 10% then turns the
      // fast tier off and disables deep — a second, distinct tightening.
      final d = governor.decide(
        const MindGovernorSignals(
          thermal: MindThermalLevel.warm,
          batteryPercent: 8,
          charging: false,
        ),
      );
      expect(d.fastIntelligenceFrequency, MindIntelligenceFrequency.off);
      expect(d.deepIntelligenceEnabled, isFalse);
      expect(d.reasons.length, greaterThanOrEqualTo(2));
    });

    test('a dimension already covered by a stricter one adds no new reason', () {
      // Hot already disables deep + reduces frequency; battery < 20% would only
      // repeat that, so it is not double-counted.
      final d = governor.decide(
        const MindGovernorSignals(
          thermal: MindThermalLevel.hot,
          batteryPercent: 15,
          charging: false,
        ),
      );
      expect(d.deepIntelligenceEnabled, isFalse);
      expect(d.reasons.length, 1);
    });
  });

  group('MindThermalLevel.fromThermalState', () {
    test('maps hardware thermal states to spec levels', () {
      expect(
        MindThermalLevel.fromThermalState(ThermalState.nominal),
        MindThermalLevel.normal,
      );
      expect(
        MindThermalLevel.fromThermalState(ThermalState.fair),
        MindThermalLevel.warm,
      );
      expect(
        MindThermalLevel.fromThermalState(ThermalState.serious),
        MindThermalLevel.hot,
      );
      expect(
        MindThermalLevel.fromThermalState(ThermalState.critical),
        MindThermalLevel.critical,
      );
    });
  });

  group('MindModelLifecycleState', () {
    test('usable and terminal classification', () {
      expect(MindModelLifecycleState.loaded.isUsable, isTrue);
      expect(MindModelLifecycleState.active.isUsable, isTrue);
      expect(MindModelLifecycleState.available.isUsable, isFalse);
      expect(MindModelLifecycleState.rejected.isTerminal, isTrue);
      expect(MindModelLifecycleState.failed.isTerminal, isTrue);
      expect(MindModelLifecycleState.loading.isTerminal, isFalse);
    });

    test('maps residency onto lifecycle', () {
      expect(
        MindModelLifecycleState.fromResidency(ModelResidency.loaded),
        MindModelLifecycleState.active,
      );
      expect(
        MindModelLifecycleState.fromResidency(ModelResidency.resident),
        MindModelLifecycleState.loaded,
      );
      expect(
        MindModelLifecycleState.fromResidency(ModelResidency.available),
        MindModelLifecycleState.available,
      );
    });
  });
}
