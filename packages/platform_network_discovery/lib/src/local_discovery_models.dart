import 'dart:async';

import 'package:core_protocol/core_protocol.dart';
import 'package:equatable/equatable.dart';

const String kAiroDiscoverySchemaVersion = '1.0.0';
const String kAiroDiscoveryServiceType = '_airotv._tcp';

enum AiroDiscoveryTransport {
  mdnsDnsSd('mdns_dns_sd'),
  manualCode('manual_code'),
  fake('fake');

  const AiroDiscoveryTransport(this.stableId);

  final String stableId;
}

enum AiroDiscoveryMode {
  advertise('advertise'),
  browse('browse'),
  advertiseAndBrowse('advertise_and_browse');

  const AiroDiscoveryMode(this.stableId);

  final String stableId;
}

enum AiroDiscoveryPermissionState {
  unknown('unknown'),
  granted('granted'),
  denied('denied'),
  restricted('restricted'),
  unavailable('unavailable');

  const AiroDiscoveryPermissionState(this.stableId);

  final String stableId;
}

enum AiroDiscoveryAdapterState {
  idle('idle'),
  advertising('advertising'),
  browsing('browsing'),
  advertisingAndBrowsing('advertising_and_browsing'),
  stopped('stopped'),
  permissionRequired('permission_required'),
  failed('failed');

  const AiroDiscoveryAdapterState(this.stableId);

  final String stableId;
}

enum AiroDiscoveryPrivacyCode {
  prohibitedFieldName('prohibited_field_name'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value');

  const AiroDiscoveryPrivacyCode(this.stableId);

  final String stableId;
}

class AiroDiscoveryPrivacyViolation extends Equatable {
  const AiroDiscoveryPrivacyViolation({
    required this.code,
    required this.field,
  });

  final AiroDiscoveryPrivacyCode code;
  final String field;

  @override
  List<Object?> get props => [code, field];
}

class AiroDiscoveryPrivacyResult extends Equatable {
  AiroDiscoveryPrivacyResult({
    required List<AiroDiscoveryPrivacyViolation> violations,
  }) : violations = List.unmodifiable(violations);

  final List<AiroDiscoveryPrivacyViolation> violations;

  bool get accepted => violations.isEmpty;

  @override
  List<Object?> get props => [violations];
}

class AiroDiscoveryPrivacyFilter {
  AiroDiscoveryPrivacyFilter({
    Set<String> prohibitedFields = _defaultProhibitedFields,
  }) : prohibitedFields = Set.unmodifiable(
         prohibitedFields.map(_normalizeFieldName),
       );

  static final AiroDiscoveryPrivacyFilter standard =
      AiroDiscoveryPrivacyFilter();

  static const Set<String> _defaultProhibitedFields = {
    'playlist',
    'playlistName',
    'playlistUrl',
    'mediaUrl',
    'sourceUrl',
    'streamUrl',
    'signedUrl',
    'url',
    'credential',
    'authorization',
    'authHeader',
    'cookie',
    'history',
    'viewingHistory',
    'localIp',
    'ipAddress',
    'localPath',
    'path',
    'query',
    'searchText',
    'voiceTranscript',
  };

  final Set<String> prohibitedFields;

  AiroDiscoveryPrivacyResult validate(Map<String, String> txtRecords) {
    final violations = <AiroDiscoveryPrivacyViolation>[];

    for (final entry in txtRecords.entries) {
      final field = entry.key;
      final normalized = _normalizeFieldName(field);
      if (prohibitedFields.contains(normalized)) {
        violations.add(
          AiroDiscoveryPrivacyViolation(
            code: AiroDiscoveryPrivacyCode.prohibitedFieldName,
            field: field,
          ),
        );
      }

      final code = _classifyStringValue(entry.value);
      if (code != null) {
        violations.add(AiroDiscoveryPrivacyViolation(code: code, field: field));
      }
    }

    return AiroDiscoveryPrivacyResult(violations: violations);
  }

  static String _normalizeFieldName(String field) {
    return field.replaceAll(RegExp('[^A-Za-z0-9]'), '').toLowerCase();
  }

  static AiroDiscoveryPrivacyCode? _classifyStringValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroDiscoveryPrivacyCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroDiscoveryPrivacyCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroDiscoveryPrivacyCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroDiscoveryPrivacyCode.credentialLikeValue;
    }

    return null;
  }
}

class AiroDiscoveryServiceRecord extends Equatable {
  AiroDiscoveryServiceRecord({
    required this.recordId,
    required this.instanceName,
    required this.hostName,
    required this.port,
    required this.advertisement,
    required this.discoveredAt,
    required this.lastSeenAt,
    this.transport = AiroDiscoveryTransport.mdnsDnsSd,
    Map<String, String> extraTxtRecords = const {},
    this.schemaVersion = kAiroDiscoverySchemaVersion,
  }) : extraTxtRecords = Map.unmodifiable(extraTxtRecords) {
    final result = AiroDiscoveryPrivacyFilter.standard.validate(toTxtRecords());
    if (!result.accepted) {
      throw ArgumentError.value(
        extraTxtRecords,
        'extraTxtRecords',
        result.violations.map((violation) => violation.code.stableId).join(','),
      );
    }
  }

  final String schemaVersion;
  final String recordId;
  final String instanceName;
  final String hostName;
  final int port;
  final AiroDiscoveryTransport transport;
  final AiroNodeCapabilityAdvertisement advertisement;
  final DateTime discoveredAt;
  final DateTime lastSeenAt;
  final Map<String, String> extraTxtRecords;

  bool isExpired(DateTime now) => advertisement.isExpired(now);

  Map<String, String> toTxtRecords() {
    final publicMap = advertisement.toPublicMap();
    return {
      'discoverySchema': schemaVersion,
      'service': kAiroDiscoveryServiceType,
      'nodeSchema': publicMap['schemaVersion'] as String,
      'protocol': '${publicMap['protocolVersion']}',
      'nodeId': publicMap['nodeId'] as String,
      'role': publicMap['role'] as String,
      'profile': publicMap['productProfile'] as String,
      'platform': publicMap['platformCategory'] as String,
      'lifecycle': publicMap['lifecycle'] as String,
      'capabilities': (publicMap['capabilities'] as List<String>).join(','),
      'expiresAt': publicMap['expiresAt'] as String,
      ...extraTxtRecords,
    };
  }

  @override
  String toString() {
    return 'AiroDiscoveryServiceRecord('
        'recordId: $recordId, '
        'service: $kAiroDiscoveryServiceType, '
        'nodeId: ${advertisement.identity.nodeId}, '
        'transport: ${transport.stableId}, '
        'lastSeenAt: $lastSeenAt'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    recordId,
    instanceName,
    hostName,
    port,
    transport,
    advertisement,
    discoveredAt,
    lastSeenAt,
    extraTxtRecords,
  ];
}

class AiroDiscoverySnapshot extends Equatable {
  AiroDiscoverySnapshot({
    required Iterable<AiroDiscoveryServiceRecord> records,
    required this.capturedAt,
    this.adapterState = AiroDiscoveryAdapterState.idle,
    this.permissionState = AiroDiscoveryPermissionState.unknown,
    this.schemaVersion = kAiroDiscoverySchemaVersion,
  }) : records = List.unmodifiable(records);

  factory AiroDiscoverySnapshot.active({
    required Iterable<AiroDiscoveryServiceRecord> records,
    required DateTime now,
    AiroDiscoveryAdapterState adapterState = AiroDiscoveryAdapterState.browsing,
    AiroDiscoveryPermissionState permissionState =
        AiroDiscoveryPermissionState.granted,
  }) {
    final byNodeId = <String, AiroDiscoveryServiceRecord>{};

    for (final record in records) {
      if (record.isExpired(now)) continue;
      final nodeId = record.advertisement.identity.nodeId;
      final existing = byNodeId[nodeId];
      if (existing == null || record.lastSeenAt.isAfter(existing.lastSeenAt)) {
        byNodeId[nodeId] = record;
      }
    }

    return AiroDiscoverySnapshot(
      records: byNodeId.values,
      capturedAt: now,
      adapterState: adapterState,
      permissionState: permissionState,
    );
  }

  final String schemaVersion;
  final List<AiroDiscoveryServiceRecord> records;
  final DateTime capturedAt;
  final AiroDiscoveryAdapterState adapterState;
  final AiroDiscoveryPermissionState permissionState;

  bool get hasRecords => records.isNotEmpty;

  AiroDiscoveryServiceRecord? recordForNode(String nodeId) {
    for (final record in records) {
      if (record.advertisement.identity.nodeId == nodeId) return record;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    records,
    capturedAt,
    adapterState,
    permissionState,
  ];
}

abstract class AiroLocalDiscoveryAdapter {
  Stream<AiroDiscoverySnapshot> get snapshots;

  Future<void> start(AiroDiscoveryMode mode);

  Future<void> stop();

  Future<AiroDiscoverySnapshot> currentSnapshot(DateTime now);
}

class AiroNoOpLocalDiscoveryAdapter implements AiroLocalDiscoveryAdapter {
  AiroNoOpLocalDiscoveryAdapter({
    this.permissionState = AiroDiscoveryPermissionState.unavailable,
  });

  final AiroDiscoveryPermissionState permissionState;
  final StreamController<AiroDiscoverySnapshot> _controller =
      StreamController<AiroDiscoverySnapshot>.broadcast();
  AiroDiscoveryAdapterState _state = AiroDiscoveryAdapterState.idle;

  @override
  Stream<AiroDiscoverySnapshot> get snapshots => _controller.stream;

  @override
  Future<void> start(AiroDiscoveryMode mode) async {
    _state = AiroDiscoveryAdapterState.permissionRequired;
    _controller.add(await currentSnapshot(DateTime.now().toUtc()));
  }

  @override
  Future<void> stop() async {
    _state = AiroDiscoveryAdapterState.stopped;
    _controller.add(await currentSnapshot(DateTime.now().toUtc()));
  }

  @override
  Future<AiroDiscoverySnapshot> currentSnapshot(DateTime now) async {
    return AiroDiscoverySnapshot(
      records: const [],
      capturedAt: now,
      adapterState: _state,
      permissionState: permissionState,
    );
  }
}

class AiroFakeLocalDiscoveryAdapter implements AiroLocalDiscoveryAdapter {
  AiroFakeLocalDiscoveryAdapter({
    this.permissionState = AiroDiscoveryPermissionState.granted,
  });

  final AiroDiscoveryPermissionState permissionState;
  final StreamController<AiroDiscoverySnapshot> _controller =
      StreamController<AiroDiscoverySnapshot>.broadcast();
  final List<AiroDiscoveryServiceRecord> _records = [];
  AiroDiscoveryAdapterState _state = AiroDiscoveryAdapterState.idle;

  @override
  Stream<AiroDiscoverySnapshot> get snapshots => _controller.stream;

  void upsert(AiroDiscoveryServiceRecord record, DateTime now) {
    _records.removeWhere(
      (existing) =>
          existing.advertisement.identity.nodeId ==
          record.advertisement.identity.nodeId,
    );
    _records.add(record);
    _controller.add(_snapshot(now));
  }

  void removeNode(String nodeId, DateTime now) {
    _records.removeWhere(
      (record) => record.advertisement.identity.nodeId == nodeId,
    );
    _controller.add(_snapshot(now));
  }

  @override
  Future<void> start(AiroDiscoveryMode mode) async {
    _state = switch (mode) {
      AiroDiscoveryMode.advertise => AiroDiscoveryAdapterState.advertising,
      AiroDiscoveryMode.browse => AiroDiscoveryAdapterState.browsing,
      AiroDiscoveryMode.advertiseAndBrowse =>
        AiroDiscoveryAdapterState.advertisingAndBrowsing,
    };
    _controller.add(_snapshot(DateTime.now().toUtc()));
  }

  @override
  Future<void> stop() async {
    _state = AiroDiscoveryAdapterState.stopped;
    _controller.add(_snapshot(DateTime.now().toUtc()));
  }

  @override
  Future<AiroDiscoverySnapshot> currentSnapshot(DateTime now) async {
    return _snapshot(now);
  }

  AiroDiscoverySnapshot _snapshot(DateTime now) {
    return AiroDiscoverySnapshot.active(
      records: _records,
      now: now,
      adapterState: _state,
      permissionState: permissionState,
    );
  }
}
