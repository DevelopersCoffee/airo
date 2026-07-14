import 'package:equatable/equatable.dart';

const String kAiroProtobufProtocolSchemaVersion = '1.0.0';
const int kAiroProtobufProtocolVersion = 1;
const int kAiroProtobufDefaultMaxPayloadBytes = 64 * 1024;

enum AiroProtobufMessageFamily {
  envelope('envelope'),
  command('command'),
  playbackState('playback_state'),
  routeHealth('route_health'),
  epgSync('epg_sync'),
  acknowledgement('acknowledgement');

  const AiroProtobufMessageFamily(this.stableId);

  final String stableId;
}

enum AiroProtobufFieldType {
  string('string'),
  int32('int32'),
  int64('int64'),
  bool('bool'),
  enumValue('enum'),
  bytes('bytes'),
  message('message'),
  repeatedString('repeated_string');

  const AiroProtobufFieldType(this.stableId);

  final String stableId;
}

enum AiroProtobufCompatibilityCode {
  accepted('accepted'),
  schemaMismatch('schema_mismatch'),
  protocolTooOld('protocol_too_old'),
  protocolTooNew('protocol_too_new'),
  duplicateFieldNumber('duplicate_field_number'),
  reservedFieldConflict('reserved_field_conflict'),
  missingRequiredField('missing_required_field'),
  oversizedPayload('oversized_payload'),
  duplicateSequence('duplicate_sequence'),
  nonPositiveSequence('non_positive_sequence'),
  unsafeStableId('unsafe_stable_id');

  const AiroProtobufCompatibilityCode(this.stableId);

  final String stableId;
}

enum AiroProtobufSafeValueRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value'),
  invalidStableId('invalid_stable_id');

  const AiroProtobufSafeValueRejectionCode(this.stableId);

  final String stableId;
}

class AiroProtobufSafeValue extends Equatable {
  const AiroProtobufSafeValue._(this.value);

  factory AiroProtobufSafeValue.stable(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroProtobufSafeValue._(value.trim());
  }

  final String value;

  static AiroProtobufSafeValueRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return AiroProtobufSafeValueRejectionCode.empty;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroProtobufSafeValueRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroProtobufSafeValueRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroProtobufSafeValueRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroProtobufSafeValueRejectionCode.credentialLikeValue;
    }
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_.-]*$').hasMatch(trimmed)) {
      return AiroProtobufSafeValueRejectionCode.invalidStableId;
    }
    return null;
  }

  @override
  String toString() => 'AiroProtobufSafeValue(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroProtobufFieldDescriptor extends Equatable {
  const AiroProtobufFieldDescriptor({
    required this.name,
    required this.number,
    required this.type,
    this.required = false,
    this.schemaVersion = kAiroProtobufProtocolSchemaVersion,
  }) : assert(number > 0);

  final String schemaVersion;
  final AiroProtobufSafeValue name;
  final int number;
  final AiroProtobufFieldType type;
  final bool required;

  @override
  String toString() {
    return 'AiroProtobufFieldDescriptor('
        'name: ${name.value}, '
        'number: $number, '
        'type: ${type.stableId}, '
        'required: $required'
        ')';
  }

  @override
  List<Object?> get props => [schemaVersion, name, number, type, required];
}

class AiroProtobufMessageDescriptor extends Equatable {
  AiroProtobufMessageDescriptor({
    required this.messageName,
    required this.family,
    required Iterable<AiroProtobufFieldDescriptor> fields,
    Set<int> reservedFieldNumbers = const {},
    this.schemaVersion = kAiroProtobufProtocolSchemaVersion,
  }) : fields = List.unmodifiable(fields),
       reservedFieldNumbers = Set.unmodifiable(reservedFieldNumbers);

  final String schemaVersion;
  final AiroProtobufSafeValue messageName;
  final AiroProtobufMessageFamily family;
  final List<AiroProtobufFieldDescriptor> fields;
  final Set<int> reservedFieldNumbers;

  Set<int> get fieldNumbers =>
      Set.unmodifiable(fields.map((field) => field.number));

  Set<int> get requiredFieldNumbers => Set.unmodifiable(
    fields.where((field) => field.required).map((field) => field.number),
  );

  @override
  String toString() {
    return 'AiroProtobufMessageDescriptor('
        'messageName: ${messageName.value}, '
        'family: ${family.stableId}, '
        'fieldCount: ${fields.length}, '
        'reservedFieldNumbers: $reservedFieldNumbers'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    messageName,
    family,
    fields,
    reservedFieldNumbers,
  ];
}

class AiroProtobufSchemaRegistry extends Equatable {
  AiroProtobufSchemaRegistry({
    required Iterable<AiroProtobufMessageDescriptor> messages,
    this.schemaVersion = kAiroProtobufProtocolSchemaVersion,
    this.protocolVersion = kAiroProtobufProtocolVersion,
    this.minProtocolVersion = kAiroProtobufProtocolVersion,
    this.maxProtocolVersion = kAiroProtobufProtocolVersion,
  }) : messages = List.unmodifiable(messages);

  final String schemaVersion;
  final int protocolVersion;
  final int minProtocolVersion;
  final int maxProtocolVersion;
  final List<AiroProtobufMessageDescriptor> messages;

  AiroProtobufMessageDescriptor? descriptorFor(
    AiroProtobufMessageFamily family,
  ) {
    for (final descriptor in messages) {
      if (descriptor.family == family) return descriptor;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    minProtocolVersion,
    maxProtocolVersion,
    messages,
  ];
}

class AiroProtobufEnvelopeProbe extends Equatable {
  AiroProtobufEnvelopeProbe({
    required this.schemaVersion,
    required this.protocolVersion,
    required this.family,
    required this.sequence,
    required this.payloadBytes,
    required Iterable<int> presentFieldNumbers,
    this.messageId,
  }) : presentFieldNumbers = Set.unmodifiable(presentFieldNumbers);

  final String schemaVersion;
  final int protocolVersion;
  final AiroProtobufMessageFamily family;
  final int sequence;
  final int payloadBytes;
  final Set<int> presentFieldNumbers;
  final String? messageId;

  @override
  String toString() {
    return 'AiroProtobufEnvelopeProbe('
        'schemaVersion: $schemaVersion, '
        'protocolVersion: $protocolVersion, '
        'family: ${family.stableId}, '
        'sequence: $sequence, '
        'payloadBytes: $payloadBytes, '
        'fieldCount: ${presentFieldNumbers.length}, '
        'hasMessageId: ${messageId != null}'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    family,
    sequence,
    payloadBytes,
    presentFieldNumbers,
    messageId,
  ];
}

class AiroProtobufCompatibilityResult extends Equatable {
  AiroProtobufCompatibilityResult({
    required this.family,
    required this.sequence,
    required Iterable<AiroProtobufCompatibilityCode> codes,
  }) : codes = List.unmodifiable(codes);

  final AiroProtobufMessageFamily family;
  final int sequence;
  final List<AiroProtobufCompatibilityCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroProtobufCompatibilityCode.accepted;

  @override
  List<Object?> get props => [family, sequence, codes];
}

class AiroProtobufCompatibilityPolicy {
  const AiroProtobufCompatibilityPolicy({
    this.maxPayloadBytes = kAiroProtobufDefaultMaxPayloadBytes,
  });

  final int maxPayloadBytes;

  AiroProtobufCompatibilityResult validate({
    required AiroProtobufSchemaRegistry registry,
    required AiroProtobufEnvelopeProbe probe,
    Set<int> acceptedSequences = const {},
  }) {
    final codes = <AiroProtobufCompatibilityCode>[];
    final descriptor = registry.descriptorFor(probe.family);

    if (probe.schemaVersion != registry.schemaVersion) {
      codes.add(AiroProtobufCompatibilityCode.schemaMismatch);
    }
    if (probe.protocolVersion < registry.minProtocolVersion) {
      codes.add(AiroProtobufCompatibilityCode.protocolTooOld);
    }
    if (probe.protocolVersion > registry.maxProtocolVersion) {
      codes.add(AiroProtobufCompatibilityCode.protocolTooNew);
    }
    if (probe.sequence <= 0) {
      codes.add(AiroProtobufCompatibilityCode.nonPositiveSequence);
    }
    if (acceptedSequences.contains(probe.sequence)) {
      codes.add(AiroProtobufCompatibilityCode.duplicateSequence);
    }
    if (probe.payloadBytes > maxPayloadBytes) {
      codes.add(AiroProtobufCompatibilityCode.oversizedPayload);
    }
    if (descriptor != null) {
      _addDescriptorCodes(descriptor, probe, codes);
    }
    final messageId = probe.messageId;
    if (messageId != null &&
        AiroProtobufSafeValue.validate(messageId) != null) {
      codes.add(AiroProtobufCompatibilityCode.unsafeStableId);
    }

    return AiroProtobufCompatibilityResult(
      family: probe.family,
      sequence: probe.sequence,
      codes: codes.isEmpty
          ? const [AiroProtobufCompatibilityCode.accepted]
          : codes,
    );
  }

  void _addDescriptorCodes(
    AiroProtobufMessageDescriptor descriptor,
    AiroProtobufEnvelopeProbe probe,
    List<AiroProtobufCompatibilityCode> codes,
  ) {
    if (descriptor.fields.length != descriptor.fieldNumbers.length) {
      codes.add(AiroProtobufCompatibilityCode.duplicateFieldNumber);
    }
    if (descriptor.reservedFieldNumbers.any(descriptor.fieldNumbers.contains)) {
      codes.add(AiroProtobufCompatibilityCode.reservedFieldConflict);
    }
    if (!probe.presentFieldNumbers.containsAll(
      descriptor.requiredFieldNumbers,
    )) {
      codes.add(AiroProtobufCompatibilityCode.missingRequiredField);
    }
  }
}

abstract interface class AiroProtobufSchemaRegistryProvider {
  AiroProtobufSchemaRegistry registry();
}

class AiroNoOpProtobufSchemaRegistryProvider
    implements AiroProtobufSchemaRegistryProvider {
  const AiroNoOpProtobufSchemaRegistryProvider();

  @override
  AiroProtobufSchemaRegistry registry() {
    return AiroProtobufSchemaRegistry(messages: const []);
  }
}

class AiroFakeProtobufSchemaRegistryProvider
    implements AiroProtobufSchemaRegistryProvider {
  const AiroFakeProtobufSchemaRegistryProvider(this._registry);

  final AiroProtobufSchemaRegistry _registry;

  @override
  AiroProtobufSchemaRegistry registry() => _registry;
}

AiroProtobufSchemaRegistry airoV2ProtobufSchemaRegistry() {
  return AiroProtobufSchemaRegistry(
    messages: [
      _message(
        name: 'AiroProtocolEnvelope',
        family: AiroProtobufMessageFamily.envelope,
        fields: const [
          _FieldSpec('schema_version', 1, AiroProtobufFieldType.string, true),
          _FieldSpec('protocol_version', 2, AiroProtobufFieldType.int32, true),
          _FieldSpec(
            'message_family',
            3,
            AiroProtobufFieldType.enumValue,
            true,
          ),
          _FieldSpec('sequence', 4, AiroProtobufFieldType.int64, true),
          _FieldSpec('message_id', 5, AiroProtobufFieldType.string, true),
          _FieldSpec(
            'issued_unix_millis',
            6,
            AiroProtobufFieldType.int64,
            true,
          ),
          _FieldSpec('payload', 7, AiroProtobufFieldType.bytes, true),
        ],
        reserved: const {100, 101, 102},
      ),
      _message(
        name: 'AiroPlaybackCommand',
        family: AiroProtobufMessageFamily.command,
        fields: const [
          _FieldSpec('command_id', 1, AiroProtobufFieldType.string, true),
          _FieldSpec('session_id', 2, AiroProtobufFieldType.string, true),
          _FieldSpec('sender_node_id', 3, AiroProtobufFieldType.string, true),
          _FieldSpec('target_node_id', 4, AiroProtobufFieldType.string, true),
          _FieldSpec('command_kind', 5, AiroProtobufFieldType.enumValue, true),
          _FieldSpec(
            'command_action',
            6,
            AiroProtobufFieldType.enumValue,
            true,
          ),
          _FieldSpec('idempotency_key', 7, AiroProtobufFieldType.string, true),
          _FieldSpec('payload_ref', 8, AiroProtobufFieldType.string, false),
        ],
      ),
      _message(
        name: 'AiroPlaybackStateSnapshot',
        family: AiroProtobufMessageFamily.playbackState,
        fields: const [
          _FieldSpec('session_id', 1, AiroProtobufFieldType.string, true),
          _FieldSpec('revision', 2, AiroProtobufFieldType.int64, true),
          _FieldSpec('phase', 3, AiroProtobufFieldType.enumValue, true),
          _FieldSpec('position_millis', 4, AiroProtobufFieldType.int64, false),
          _FieldSpec('duration_millis', 5, AiroProtobufFieldType.int64, false),
          _FieldSpec('owner_node_id', 6, AiroProtobufFieldType.string, true),
          _FieldSpec('playback_node_id', 7, AiroProtobufFieldType.string, true),
          _FieldSpec('route_id', 8, AiroProtobufFieldType.string, true),
        ],
      ),
      _message(
        name: 'AiroRouteHealthUpdate',
        family: AiroProtobufMessageFamily.routeHealth,
        fields: const [
          _FieldSpec('event_id', 1, AiroProtobufFieldType.string, true),
          _FieldSpec('session_id', 2, AiroProtobufFieldType.string, true),
          _FieldSpec('route_id', 3, AiroProtobufFieldType.string, true),
          _FieldSpec('sequence', 4, AiroProtobufFieldType.int64, true),
          _FieldSpec('health_level', 5, AiroProtobufFieldType.enumValue, true),
          _FieldSpec('failure_code', 6, AiroProtobufFieldType.string, false),
          _FieldSpec('diagnostic_ref', 7, AiroProtobufFieldType.string, false),
        ],
      ),
      _message(
        name: 'AiroCompactEpgSync',
        family: AiroProtobufMessageFamily.epgSync,
        fields: const [
          _FieldSpec('sync_id', 1, AiroProtobufFieldType.string, true),
          _FieldSpec('source_node_id', 2, AiroProtobufFieldType.string, true),
          _FieldSpec('target_node_id', 3, AiroProtobufFieldType.string, true),
          _FieldSpec(
            'window_start_unix_millis',
            4,
            AiroProtobufFieldType.int64,
            true,
          ),
          _FieldSpec(
            'window_end_unix_millis',
            5,
            AiroProtobufFieldType.int64,
            true,
          ),
          _FieldSpec('entry_count', 6, AiroProtobufFieldType.int32, true),
          _FieldSpec('payload_ref', 7, AiroProtobufFieldType.string, false),
        ],
      ),
      _message(
        name: 'AiroProtocolAcknowledgement',
        family: AiroProtobufMessageFamily.acknowledgement,
        fields: const [
          _FieldSpec('message_id', 1, AiroProtobufFieldType.string, true),
          _FieldSpec('sequence', 2, AiroProtobufFieldType.int64, true),
          _FieldSpec('status', 3, AiroProtobufFieldType.enumValue, true),
          _FieldSpec('stable_code', 4, AiroProtobufFieldType.string, false),
        ],
      ),
    ],
  );
}

AiroProtobufMessageDescriptor _message({
  required String name,
  required AiroProtobufMessageFamily family,
  required List<_FieldSpec> fields,
  Set<int> reserved = const {},
}) {
  return AiroProtobufMessageDescriptor(
    messageName: AiroProtobufSafeValue.stable(name),
    family: family,
    reservedFieldNumbers: reserved,
    fields: fields
        .map(
          (field) => AiroProtobufFieldDescriptor(
            name: AiroProtobufSafeValue.stable(field.name),
            number: field.number,
            type: field.type,
            required: field.required,
          ),
        )
        .toList(growable: false),
  );
}

class _FieldSpec {
  const _FieldSpec(this.name, this.number, this.type, this.required);

  final String name;
  final int number;
  final AiroProtobufFieldType type;
  final bool required;
}
