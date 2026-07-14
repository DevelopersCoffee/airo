import 'package:core_commands/core_commands.dart';
import 'package:core_pairing/core_pairing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo command envelope', () {
    final issuedAt = DateTime.utc(2026, 7, 14, 12);
    final expiresAt = issuedAt.add(const Duration(seconds: 30));

    AiroCommandEnvelope envelope({
      String commandId = 'command-1',
      String targetNodeId = 'receiver-tv-1',
      AiroPairingScope requiredScope = AiroPairingScope.playbackControl,
      DateTime? expiresAtOverride,
      int protocolVersion = kAiroCommandProtocolVersion,
      String schemaVersion = kAiroCommandSchemaVersion,
      String idempotencyKey = 'idempotency-1',
      AiroCommandPayload? payload,
    }) {
      return AiroCommandEnvelope(
        commandId: commandId,
        sessionId: 'session-1',
        senderNodeId: 'phone-1',
        targetNodeId: targetNodeId,
        kind: AiroCommandKind.playback,
        action: AiroCommandAction.play,
        requiredScope: requiredScope,
        issuedAt: issuedAt,
        expiresAt: expiresAtOverride ?? expiresAt,
        idempotencyKey: idempotencyKey,
        protocolVersion: protocolVersion,
        schemaVersion: schemaVersion,
        payload: payload,
      );
    }

    AiroCommandValidationPolicy policy({
      Set<AiroPairingScope> grantedScopes = const {
        AiroPairingScope.playbackControl,
        AiroPairingScope.textInput,
      },
      Set<String> seenIdempotencyKeys = const {},
    }) {
      return AiroCommandValidationPolicy(
        targetNodeId: 'receiver-tv-1',
        grantedScopes: grantedScopes,
        seenIdempotencyKeys: seenIdempotencyKeys,
      );
    }

    test('validates a scoped unexpired envelope', () {
      final result = policy().evaluate(
        envelope: envelope(),
        now: issuedAt.add(const Duration(seconds: 1)),
      );
      final publicMap = envelope().toPublicMap();

      expect(result.accepted, isTrue);
      expect(publicMap['schemaVersion'], kAiroCommandSchemaVersion);
      expect(publicMap['protocolVersion'], kAiroCommandProtocolVersion);
      expect(publicMap['kind'], 'playback');
      expect(publicMap['requiredScope'], 'playback_control');
    });

    test(
      'rejects expired, unsupported version, target, scope, and duplicate',
      () {
        final result =
            policy(
              grantedScopes: const {AiroPairingScope.textInput},
              seenIdempotencyKeys: const {'idempotency-1'},
            ).evaluate(
              envelope: envelope(
                targetNodeId: 'other-tv',
                requiredScope: AiroPairingScope.playbackControl,
                expiresAtOverride: issuedAt,
                protocolVersion: kAiroCommandProtocolVersion + 1,
              ),
              now: issuedAt.add(const Duration(seconds: 1)),
            );

        expect(result.has(AiroCommandValidationCode.expired), isTrue);
        expect(result.has(AiroCommandValidationCode.protocolTooNew), isTrue);
        expect(result.has(AiroCommandValidationCode.targetMismatch), isTrue);
        expect(result.has(AiroCommandValidationCode.scopeMissing), isTrue);
        expect(
          result.has(AiroCommandValidationCode.duplicateIdempotencyKey),
          isTrue,
        );
      },
    );

    test('rejects schema and old protocol mismatches', () {
      final result = policy().evaluate(
        envelope: envelope(
          schemaVersion: '0.9.0',
          protocolVersion: kAiroCommandProtocolVersion - 1,
        ),
        now: issuedAt.add(const Duration(seconds: 1)),
      );

      expect(result.has(AiroCommandValidationCode.schemaMismatch), isTrue);
      expect(result.has(AiroCommandValidationCode.protocolTooOld), isTrue);
    });

    test('payload rejects unsafe fields and values deterministically', () {
      expect(
        () => AiroCommandPayload.safe(const {'playlistUrl': 'hidden'}),
        throwsArgumentError,
      );
      expect(
        () => AiroCommandPayload.safe(const {'note': 'https://example.com'}),
        throwsArgumentError,
      );
      expect(
        () => AiroCommandPayload.safe(const {'note': '/Users/example/list'}),
        throwsArgumentError,
      );
      expect(
        () => AiroCommandPayload.safe(const {'note': 'seen 192.168.1.10'}),
        throwsArgumentError,
      );
      expect(
        () => AiroCommandPayload.safe(const {'note': 'Bearer abc.def'}),
        throwsArgumentError,
      );
    });

    test('string output redacts command payload values', () {
      final command = envelope(
        payload: AiroCommandPayload.safe(const {'positionMs': '12000'}),
      );
      final result = AiroCommandResult(
        commandId: command.commandId,
        status: AiroCommandResultStatus.completed,
        completedAt: issuedAt,
        payload: AiroCommandPayload.safe(const {'positionMs': '12000'}),
      );

      expect(command.toString(), isNot(contains('12000')));
      expect(result.toString(), isNot(contains('12000')));
      expect(command.toString(), contains('redactedKeys'));
      expect(result.toString(), contains('redactedKeys'));
    });

    test('no-op dispatcher returns deterministic unsupported result', () async {
      const dispatcher = AiroNoOpCommandDispatcher();

      final result = await dispatcher.dispatch(envelope());

      expect(result.commandId, 'command-1');
      expect(result.status, AiroCommandResultStatus.unsupported);
      expect(result.code, 'dispatcher_unavailable');
    });

    test(
      'fake dispatcher records envelopes and returns canned results',
      () async {
        final command = envelope(commandId: 'command-canned');
        final dispatcher = AiroFakeCommandDispatcher(
          cannedResults: {
            'command-canned': AiroCommandResult(
              commandId: 'command-canned',
              status: AiroCommandResultStatus.completed,
              completedAt: issuedAt,
            ),
          },
        );

        final result = await dispatcher.dispatch(command);

        expect(dispatcher.dispatched, [command]);
        expect(result.status, AiroCommandResultStatus.completed);
      },
    );
  });
}
