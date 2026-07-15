import 'package:core_release/core_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo v2 release readiness preflight', () {
    const runner = AiroV2ReleaseReadinessPreflightRunner();

    Map<String, AiroV2ReleaseGateStatus> allRequiredReady() {
      return {
        for (final gate in AiroV2ReleaseReadinessPreflightRunner.defaultGates)
          if (gate.requiredForPublicRelease)
            gate.id: AiroV2ReleaseGateStatus.ready,
      };
    }

    test('blocks public readiness when required gates are unknown', () {
      final preflight = runner.run();

      expect(preflight.publicReady, isFalse);
      expect(preflight.findings, isNotEmpty);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroV2ReleaseReadinessFindingCode.unknownRequiredGate),
      );
      expect(
        preflight.findings.map((finding) => finding.gateId),
        contains('firebase_mobile_clients'),
      );
    });

    test('tracks open device and QA evidence blockers as required gates', () {
      final gateIds = AiroV2ReleaseReadinessPreflightRunner.defaultGates.map(
        (gate) => gate.id,
      );

      expect(
        gateIds,
        containsAll([
          'tv_ui_dpad_qualification',
          'cast_active_receiver_switching',
          'cast_v1_device_qa',
          'ipad_air_qualification',
          'memory_playback_soak',
        ]),
      );

      final preflight = runner.run();
      expect(
        preflight.findings
            .where((finding) => finding.blocking)
            .map((finding) => finding.gateId),
        containsAll([
          'tv_ui_dpad_qualification',
          'cast_active_receiver_switching',
          'cast_v1_device_qa',
          'ipad_air_qualification',
          'memory_playback_soak',
        ]),
      );
    });

    test('accepts public readiness when required gates are ready', () {
      final preflight = runner.run(overrides: allRequiredReady());

      expect(preflight.publicReady, isTrue);
      expect(preflight.findings.where((finding) => finding.blocking), isEmpty);
    });

    test('treats waived and not-in-scope gates as explicit decisions', () {
      final overrides = allRequiredReady()
        ..['release_qualification'] = AiroV2ReleaseGateStatus.waived
        ..['kgp_scope_decision'] = AiroV2ReleaseGateStatus.notInScope;

      final preflight = runner.run(overrides: overrides);

      expect(preflight.publicReady, isTrue);
      expect(
        preflight.gates
            .where((gate) => gate.id == 'release_qualification')
            .single
            .status,
        AiroV2ReleaseGateStatus.waived,
      );
    });

    test(
      'optional macOS gate can be deferred without blocking Android wave',
      () {
        final preflight = runner.run(
          overrides: {
            ...allRequiredReady(),
            'macos_signing': AiroV2ReleaseGateStatus.deferred,
          },
        );

        expect(preflight.publicReady, isTrue);
        expect(preflight.findings, isEmpty);
      },
    );

    test('reports unknown gate overrides as blocking findings', () {
      final preflight = runner.run(
        overrides: {
          ...allRequiredReady(),
          'not_a_gate': AiroV2ReleaseGateStatus.ready,
        },
      );

      expect(preflight.publicReady, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroV2ReleaseReadinessFindingCode.missingRequiredGate),
      );
    });

    test('renders markdown and public maps without secret-shaped fields', () {
      final preflight = runner.run(
        overrides: allRequiredReady(),
        notes: const {
          'android_signing': 'Key owner confirmed in private runbook.',
        },
      );
      final markdown = preflight.toMarkdown();
      final publicMap = preflight.toPublicMap().toString();

      expect(markdown, contains('# V2 Release Readiness Preflight'));
      expect(markdown, contains('android_signing'));
      expect(markdown, contains('Key owner confirmed'));
      expect(publicMap, isNot(contains('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON')));
      expect(publicMap, isNot(contains('ANDROID_RELEASE_KEYSTORE_BASE64')));
    });
  });
}
