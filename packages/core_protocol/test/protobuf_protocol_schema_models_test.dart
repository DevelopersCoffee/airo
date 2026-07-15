import 'package:core_protocol/core_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo protobuf protocol schema registry', () {
    const policy = AiroProtobufCompatibilityPolicy();

    test('defines required v2 message families and stable fields', () {
      final registry = airoV2ProtobufSchemaRegistry();

      expect(registry.schemaVersion, kAiroProtobufProtocolSchemaVersion);
      expect(registry.protocolVersion, kAiroProtobufProtocolVersion);
      for (final family in AiroProtobufMessageFamily.values) {
        expect(registry.descriptorFor(family), isNotNull);
      }

      final envelope = registry.descriptorFor(
        AiroProtobufMessageFamily.envelope,
      )!;
      expect(envelope.messageName.value, 'AiroProtocolEnvelope');
      expect(envelope.requiredFieldNumbers, containsAll({1, 2, 3, 4, 5, 6, 7}));
      expect(envelope.reservedFieldNumbers, containsAll({100, 101, 102}));
    });

    test('accepts compatible envelope probe with required fields', () {
      final registry = airoV2ProtobufSchemaRegistry();
      final result = policy.validate(
        registry: registry,
        probe: AiroProtobufEnvelopeProbe(
          schemaVersion: kAiroProtobufProtocolSchemaVersion,
          protocolVersion: kAiroProtobufProtocolVersion,
          family: AiroProtobufMessageFamily.envelope,
          sequence: 1,
          payloadBytes: 256,
          messageId: 'message-1',
          presentFieldNumbers: {1, 2, 3, 4, 5, 6, 7},
        ),
      );

      expect(result.accepted, isTrue);
    });

    test('rejects schema protocol replay sequence and size failures', () {
      final registry = airoV2ProtobufSchemaRegistry();
      final result = policy.validate(
        registry: registry,
        acceptedSequences: const {7},
        probe: AiroProtobufEnvelopeProbe(
          schemaVersion: '2.0.0',
          protocolVersion: 99,
          family: AiroProtobufMessageFamily.command,
          sequence: 7,
          payloadBytes: kAiroProtobufDefaultMaxPayloadBytes + 1,
          messageId: 'message-7',
          presentFieldNumbers: {1, 2, 3, 4, 5, 6, 7},
        ),
      );

      expect(
        result.codes,
        contains(AiroProtobufCompatibilityCode.schemaMismatch),
      );
      expect(
        result.codes,
        contains(AiroProtobufCompatibilityCode.protocolTooNew),
      );
      expect(
        result.codes,
        contains(AiroProtobufCompatibilityCode.duplicateSequence),
      );
      expect(
        result.codes,
        contains(AiroProtobufCompatibilityCode.oversizedPayload),
      );
    });

    test('rejects missing required fields and unsafe message ids', () {
      final registry = airoV2ProtobufSchemaRegistry();
      final result = policy.validate(
        registry: registry,
        probe: AiroProtobufEnvelopeProbe(
          schemaVersion: kAiroProtobufProtocolSchemaVersion,
          protocolVersion: kAiroProtobufProtocolVersion,
          family: AiroProtobufMessageFamily.routeHealth,
          sequence: 2,
          payloadBytes: 128,
          messageId: 'https://example.com/message',
          presentFieldNumbers: {1, 2},
        ),
      );

      expect(
        result.codes,
        contains(AiroProtobufCompatibilityCode.missingRequiredField),
      );
      expect(
        result.codes,
        contains(AiroProtobufCompatibilityCode.unsafeStableId),
      );
    });

    test('detects duplicate and reserved field number conflicts', () {
      final registry = AiroProtobufSchemaRegistry(
        messages: [
          AiroProtobufMessageDescriptor(
            messageName: AiroProtobufSafeValue.stable('AiroBrokenMessage'),
            family: AiroProtobufMessageFamily.acknowledgement,
            reservedFieldNumbers: const {2},
            fields: [
              AiroProtobufFieldDescriptor(
                name: AiroProtobufSafeValue.stable('message_id'),
                number: 1,
                type: AiroProtobufFieldType.string,
                required: true,
              ),
              AiroProtobufFieldDescriptor(
                name: AiroProtobufSafeValue.stable('sequence'),
                number: 2,
                type: AiroProtobufFieldType.int64,
                required: true,
              ),
              AiroProtobufFieldDescriptor(
                name: AiroProtobufSafeValue.stable('duplicate_sequence'),
                number: 2,
                type: AiroProtobufFieldType.int64,
              ),
            ],
          ),
        ],
      );

      final result = policy.validate(
        registry: registry,
        probe: AiroProtobufEnvelopeProbe(
          schemaVersion: kAiroProtobufProtocolSchemaVersion,
          protocolVersion: kAiroProtobufProtocolVersion,
          family: AiroProtobufMessageFamily.acknowledgement,
          sequence: 3,
          payloadBytes: 128,
          messageId: 'ack-3',
          presentFieldNumbers: {1, 2},
        ),
      );

      expect(
        result.codes,
        contains(AiroProtobufCompatibilityCode.duplicateFieldNumber),
      );
      expect(
        result.codes,
        contains(AiroProtobufCompatibilityCode.reservedFieldConflict),
      );
    });

    test('safe value rejects raw transport and credential data', () {
      expect(
        () => AiroProtobufSafeValue.stable('https://example.com/stream.m3u8'),
        throwsArgumentError,
      );
      expect(
        () => AiroProtobufSafeValue.stable('/Users/me/media.mp4'),
        throwsArgumentError,
      );
      expect(
        () => AiroProtobufSafeValue.stable('192.168.1.30'),
        throwsArgumentError,
      );
      expect(
        () => AiroProtobufSafeValue.stable('Bearer abc123'),
        throwsArgumentError,
      );
    });

    test('registry adapters are deterministic', () {
      const noop = AiroNoOpProtobufSchemaRegistryProvider();
      final registry = airoV2ProtobufSchemaRegistry();
      final fake = AiroFakeProtobufSchemaRegistryProvider(registry);

      expect(noop.registry().messages, isEmpty);
      expect(
        fake.registry().descriptorFor(AiroProtobufMessageFamily.epgSync),
        isNotNull,
      );
    });
  });
}
