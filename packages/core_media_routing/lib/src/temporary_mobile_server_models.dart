import 'dart:async';

import 'package:equatable/equatable.dart';

import 'media_location_models.dart';

const String kAiroTemporaryMobileServerSchemaVersion = '1.0.0';

enum AiroTemporaryMobileServerCapability {
  lanOnly('lan_only'),
  rangeRequests('range_requests'),
  probeRequests('head_probe_requests'),
  entityValidation('entity_validation'),
  autoShutdownOnExpiry('auto_shutdown_on_expiry'),
  idleShutdown('idle_shutdown');

  const AiroTemporaryMobileServerCapability(this.stableId);

  final String stableId;
}

enum AiroTemporaryMobileThermalState {
  normal('normal'),
  warm('warm'),
  hot('hot'),
  critical('critical');

  const AiroTemporaryMobileThermalState(this.stableId);

  final String stableId;
}

enum AiroTemporaryMobileServerRequestMethod {
  get('GET'),
  head('HEAD');

  const AiroTemporaryMobileServerRequestMethod(this.stableId);

  final String stableId;
}

enum AiroTemporaryMobileServerServingStatus {
  ok('200'),
  partialContent('206'),
  reject('reject');

  const AiroTemporaryMobileServerServingStatus(this.stableId);

  final String stableId;
}

enum AiroTemporaryMobileServerValidationCode {
  accepted('accepted'),
  serverUnavailable('server_unavailable'),
  expired('expired'),
  idleTimeoutExceeded('idle_timeout_exceeded'),
  localNetworkRequired('local_network_required'),
  trustedReceiverRequired('trusted_receiver_required'),
  receiverNotAllowed('receiver_not_allowed'),
  grantAudienceMismatch('grant_audience_mismatch'),
  grantExpired('grant_expired'),
  grantScopeMissing('grant_scope_missing'),
  rangeRequestsRequired('range_requests_required'),
  probeRequestsRequired('head_probe_requests_required'),
  entityValidationRequired('entity_validation_required'),
  autoShutdownRequired('auto_shutdown_required'),
  idleShutdownRequired('idle_shutdown_required'),
  batteryTooLow('battery_too_low'),
  thermalTooHigh('thermal_too_high'),
  concurrentReceiverLimitExceeded('concurrent_receiver_limit_exceeded');

  const AiroTemporaryMobileServerValidationCode(this.stableId);

  final String stableId;
}

enum AiroTemporaryMobileServerServingCode {
  accepted('accepted'),
  unsupportedMethod('unsupported_method'),
  rangeHeaderRequired('range_header_required'),
  rangeHeaderMalformed('range_header_malformed'),
  multiRangeUnsupported('multi_range_unsupported'),
  rangeNotSatisfiable('range_not_satisfiable'),
  unknownMediaLength('unknown_media_length'),
  entityValidatorMissing('entity_validator_missing'),
  cancelled('cancelled');

  const AiroTemporaryMobileServerServingCode(this.stableId);

  final String stableId;
}

class AiroTemporaryMobileServerSnapshot extends Equatable {
  AiroTemporaryMobileServerSnapshot({
    required this.serverId,
    required this.hostNodeId,
    required this.locationId,
    required this.mediaId,
    required this.accessGrant,
    required this.startedAt,
    required this.expiresAt,
    required this.batteryPercent,
    required this.thermalState,
    required Set<String> allowedReceiverNodeIds,
    required Set<AiroTemporaryMobileServerCapability> capabilities,
    this.lastActivityAt,
    this.idleTimeout = const Duration(minutes: 2),
    this.requiresTrustedReceiverScope = true,
    this.isCharging = false,
    this.activeReceiverCount = 0,
    this.schemaVersion = kAiroTemporaryMobileServerSchemaVersion,
  }) : allowedReceiverNodeIds = Set.unmodifiable(allowedReceiverNodeIds),
       capabilities = Set.unmodifiable(capabilities),
       assert(batteryPercent >= 0 && batteryPercent <= 100),
       assert(activeReceiverCount >= 0);

  final String schemaVersion;
  final String serverId;
  final String hostNodeId;
  final String locationId;
  final String mediaId;
  final AiroRouteAccessGrant accessGrant;
  final DateTime startedAt;
  final DateTime expiresAt;
  final DateTime? lastActivityAt;
  final Duration idleTimeout;
  final Set<String> allowedReceiverNodeIds;
  final Set<AiroTemporaryMobileServerCapability> capabilities;
  final bool requiresTrustedReceiverScope;
  final int batteryPercent;
  final bool isCharging;
  final AiroTemporaryMobileThermalState thermalState;
  final int activeReceiverCount;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  bool isIdleTimedOut(DateTime now) {
    final lastActivity = lastActivityAt ?? startedAt;
    return !now.isBefore(lastActivity.add(idleTimeout));
  }

  bool allowsReceiver(String receiverNodeId) =>
      allowedReceiverNodeIds.contains(receiverNodeId);

  bool supports(AiroTemporaryMobileServerCapability capability) =>
      capabilities.contains(capability);

  @override
  String toString() {
    return 'AiroTemporaryMobileServerSnapshot('
        'serverId: $serverId, '
        'hostNodeId: $hostNodeId, '
        'locationId: $locationId, '
        'mediaId: $mediaId, '
        'grantId: ${accessGrant.grantId}, '
        'audienceNodeId: ${accessGrant.audienceNodeId}, '
        'capabilities: ${capabilities.map((capability) => capability.stableId).toList()}, '
        'expiresAt: $expiresAt, '
        'access: redacted'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    serverId,
    hostNodeId,
    locationId,
    mediaId,
    accessGrant,
    startedAt,
    expiresAt,
    lastActivityAt,
    idleTimeout,
    allowedReceiverNodeIds,
    capabilities,
    requiresTrustedReceiverScope,
    batteryPercent,
    isCharging,
    thermalState,
    activeReceiverCount,
  ];
}

class AiroTemporaryMobileServerServingRequest extends Equatable {
  const AiroTemporaryMobileServerServingRequest({
    required this.requestId,
    required this.method,
    required this.receiverNodeId,
    required this.now,
    required this.mediaLengthBytes,
    required this.entityValidator,
    this.rangeHeader,
    this.hasLocalNetworkScope = false,
    this.hasTrustedReceiverScope = false,
    this.cancelled = false,
    this.requiresRangeRequest = true,
  }) : assert(mediaLengthBytes >= 0);

  final String requestId;
  final AiroTemporaryMobileServerRequestMethod method;
  final String receiverNodeId;
  final DateTime now;
  final int mediaLengthBytes;
  final String entityValidator;
  final String? rangeHeader;
  final bool hasLocalNetworkScope;
  final bool hasTrustedReceiverScope;
  final bool cancelled;
  final bool requiresRangeRequest;

  AiroTemporaryMobileServerValidationContext get validationContext {
    return AiroTemporaryMobileServerValidationContext(
      now: now,
      receiverNodeId: receiverNodeId,
      hasLocalNetworkScope: hasLocalNetworkScope,
      hasTrustedReceiverScope: hasTrustedReceiverScope,
    );
  }

  @override
  List<Object?> get props => [
    requestId,
    method,
    receiverNodeId,
    now,
    mediaLengthBytes,
    entityValidator,
    rangeHeader,
    hasLocalNetworkScope,
    hasTrustedReceiverScope,
    cancelled,
    requiresRangeRequest,
  ];
}

class AiroTemporaryMobileServerByteRange extends Equatable {
  const AiroTemporaryMobileServerByteRange({
    required this.start,
    required this.end,
    required this.totalLength,
  }) : assert(start >= 0),
       assert(end >= start),
       assert(totalLength > 0);

  final int start;
  final int end;
  final int totalLength;

  int get contentLength => end - start + 1;

  String get contentRangeHeader => 'bytes $start-$end/$totalLength';

  Map<String, Object?> toPublicMap() {
    return {
      'start': start,
      'end': end,
      'totalLength': totalLength,
      'contentLength': contentLength,
    };
  }

  @override
  List<Object?> get props => [start, end, totalLength];
}

class AiroTemporaryMobileServerServingDecision extends Equatable {
  AiroTemporaryMobileServerServingDecision({
    required this.serverId,
    required this.requestId,
    required this.status,
    required List<AiroTemporaryMobileServerValidationCode> validationCodes,
    required List<AiroTemporaryMobileServerServingCode> servingCodes,
    required Map<String, String> responseHeaders,
    this.range,
  }) : validationCodes = List.unmodifiable(validationCodes),
       servingCodes = List.unmodifiable(servingCodes),
       responseHeaders = Map.unmodifiable(responseHeaders);

  final String serverId;
  final String requestId;
  final AiroTemporaryMobileServerServingStatus status;
  final List<AiroTemporaryMobileServerValidationCode> validationCodes;
  final List<AiroTemporaryMobileServerServingCode> servingCodes;
  final Map<String, String> responseHeaders;
  final AiroTemporaryMobileServerByteRange? range;

  bool get accepted =>
      status != AiroTemporaryMobileServerServingStatus.reject &&
      validationCodes.length == 1 &&
      validationCodes.single ==
          AiroTemporaryMobileServerValidationCode.accepted &&
      servingCodes.length == 1 &&
      servingCodes.single == AiroTemporaryMobileServerServingCode.accepted;

  bool get emitsBody =>
      accepted &&
      status == AiroTemporaryMobileServerServingStatus.partialContent;

  Map<String, Object?> toPublicMap() {
    return {
      'serverId': serverId,
      'requestId': requestId,
      'status': status.stableId,
      'validationCodes': _validationCodeStableIds(validationCodes),
      'servingCodes': _servingCodeStableIds(servingCodes),
      'responseHeaders': responseHeaders,
      'range': range?.toPublicMap(),
    };
  }

  @override
  List<Object?> get props => [
    serverId,
    requestId,
    status,
    validationCodes,
    servingCodes,
    responseHeaders,
    range,
  ];
}

class AiroTemporaryMobileServerValidationContext extends Equatable {
  const AiroTemporaryMobileServerValidationContext({
    required this.now,
    required this.receiverNodeId,
    this.hasLocalNetworkScope = false,
    this.hasTrustedReceiverScope = false,
  });

  final DateTime now;
  final String receiverNodeId;
  final bool hasLocalNetworkScope;
  final bool hasTrustedReceiverScope;

  @override
  List<Object?> get props => [
    now,
    receiverNodeId,
    hasLocalNetworkScope,
    hasTrustedReceiverScope,
  ];
}

class AiroTemporaryMobileServerValidationResult extends Equatable {
  AiroTemporaryMobileServerValidationResult({
    required this.serverId,
    required List<AiroTemporaryMobileServerValidationCode> codes,
  }) : codes = List.unmodifiable(codes);

  final String serverId;
  final List<AiroTemporaryMobileServerValidationCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroTemporaryMobileServerValidationCode.accepted;

  @override
  List<Object?> get props => [serverId, codes];
}

class AiroTemporaryMobileServerServingPolicy {
  const AiroTemporaryMobileServerServingPolicy({
    this.validationPolicy = const AiroTemporaryMobileServerPolicy(),
  });

  final AiroTemporaryMobileServerPolicy validationPolicy;

  AiroTemporaryMobileServerServingDecision evaluate({
    required AiroTemporaryMobileServerSnapshot snapshot,
    required AiroTemporaryMobileServerServingRequest request,
  }) {
    final validation = validationPolicy.validate(
      snapshot: snapshot,
      context: request.validationContext,
    );
    if (!validation.accepted) {
      return AiroTemporaryMobileServerServingDecision(
        serverId: snapshot.serverId,
        requestId: request.requestId,
        status: AiroTemporaryMobileServerServingStatus.reject,
        validationCodes: validation.codes,
        servingCodes: const [],
        responseHeaders: const {},
      );
    }

    final servingCodes = _servingCodesFor(request);
    if (servingCodes.isNotEmpty) {
      return AiroTemporaryMobileServerServingDecision(
        serverId: snapshot.serverId,
        requestId: request.requestId,
        status: AiroTemporaryMobileServerServingStatus.reject,
        validationCodes: validation.codes,
        servingCodes: servingCodes,
        responseHeaders: const {},
      );
    }

    final range = _rangeFor(request);
    if (range == null &&
        request.method == AiroTemporaryMobileServerRequestMethod.get) {
      return AiroTemporaryMobileServerServingDecision(
        serverId: snapshot.serverId,
        requestId: request.requestId,
        status: AiroTemporaryMobileServerServingStatus.reject,
        validationCodes: validation.codes,
        servingCodes: const [
          AiroTemporaryMobileServerServingCode.rangeHeaderMalformed,
        ],
        responseHeaders: const {},
      );
    }

    final responseHeaders = _headersFor(request, range);
    return AiroTemporaryMobileServerServingDecision(
      serverId: snapshot.serverId,
      requestId: request.requestId,
      status: range == null
          ? AiroTemporaryMobileServerServingStatus.ok
          : AiroTemporaryMobileServerServingStatus.partialContent,
      validationCodes: validation.codes,
      servingCodes: const [AiroTemporaryMobileServerServingCode.accepted],
      responseHeaders: responseHeaders,
      range: range,
    );
  }

  List<AiroTemporaryMobileServerServingCode> _servingCodesFor(
    AiroTemporaryMobileServerServingRequest request,
  ) {
    final codes = <AiroTemporaryMobileServerServingCode>[];
    if (request.cancelled) {
      codes.add(AiroTemporaryMobileServerServingCode.cancelled);
    }
    if (request.mediaLengthBytes <= 0) {
      codes.add(AiroTemporaryMobileServerServingCode.unknownMediaLength);
    }
    if (request.entityValidator.trim().isEmpty) {
      codes.add(AiroTemporaryMobileServerServingCode.entityValidatorMissing);
    }
    if (request.method == AiroTemporaryMobileServerRequestMethod.get &&
        request.requiresRangeRequest &&
        (request.rangeHeader == null || request.rangeHeader!.trim().isEmpty)) {
      codes.add(AiroTemporaryMobileServerServingCode.rangeHeaderRequired);
    }
    final rangeHeader = request.rangeHeader?.trim();
    if (rangeHeader != null && rangeHeader.isNotEmpty) {
      if (rangeHeader.contains(',')) {
        codes.add(AiroTemporaryMobileServerServingCode.multiRangeUnsupported);
      } else if (!rangeHeader.startsWith('bytes=')) {
        codes.add(AiroTemporaryMobileServerServingCode.rangeHeaderMalformed);
      } else if (_rangeFor(request) == null) {
        codes.add(AiroTemporaryMobileServerServingCode.rangeNotSatisfiable);
      }
    }
    return List.unmodifiable(codes);
  }

  AiroTemporaryMobileServerByteRange? _rangeFor(
    AiroTemporaryMobileServerServingRequest request,
  ) {
    final header = request.rangeHeader?.trim();
    if (header == null || header.isEmpty) return null;
    if (!header.startsWith('bytes=') || header.contains(',')) return null;
    if (request.mediaLengthBytes <= 0) return null;

    final spec = header.substring('bytes='.length);
    final separatorIndex = spec.indexOf('-');
    if (separatorIndex < 0) return null;

    final startText = spec.substring(0, separatorIndex);
    final endText = spec.substring(separatorIndex + 1);
    if (startText.isEmpty && endText.isEmpty) return null;

    int start;
    int end;
    if (startText.isEmpty) {
      final suffixLength = int.tryParse(endText);
      if (suffixLength == null || suffixLength <= 0) return null;
      start = request.mediaLengthBytes - suffixLength;
      if (start < 0) start = 0;
      end = request.mediaLengthBytes - 1;
    } else {
      final parsedStart = int.tryParse(startText);
      final parsedEnd = endText.isEmpty ? null : int.tryParse(endText);
      if (parsedStart == null || parsedStart < 0) return null;
      if (endText.isNotEmpty && parsedEnd == null) return null;
      start = parsedStart;
      end = parsedEnd ?? request.mediaLengthBytes - 1;
      if (end >= request.mediaLengthBytes) {
        end = request.mediaLengthBytes - 1;
      }
    }

    if (start >= request.mediaLengthBytes || end < start) return null;
    return AiroTemporaryMobileServerByteRange(
      start: start,
      end: end,
      totalLength: request.mediaLengthBytes,
    );
  }

  Map<String, String> _headersFor(
    AiroTemporaryMobileServerServingRequest request,
    AiroTemporaryMobileServerByteRange? range,
  ) {
    final headers = <String, String>{
      'Accept-Ranges': 'bytes',
      'ETag': request.entityValidator,
    };
    if (range == null) {
      headers['Content-Length'] = request.mediaLengthBytes.toString();
    } else {
      headers['Content-Length'] = range.contentLength.toString();
      headers['Content-Range'] = range.contentRangeHeader;
    }
    return Map.unmodifiable(headers);
  }
}

class AiroTemporaryMobileServerPolicy {
  const AiroTemporaryMobileServerPolicy({
    this.minBatteryPercent = 20,
    this.maxAllowedThermalState = AiroTemporaryMobileThermalState.warm,
    this.maxConcurrentReceivers = 1,
    this.requiredAccessScopes = const {
      AiroRouteAccessScope.playbackRead,
      AiroRouteAccessScope.rangeRead,
      AiroRouteAccessScope.probeRead,
    },
    this.requiredCapabilities = const {
      AiroTemporaryMobileServerCapability.lanOnly,
      AiroTemporaryMobileServerCapability.rangeRequests,
      AiroTemporaryMobileServerCapability.probeRequests,
      AiroTemporaryMobileServerCapability.entityValidation,
      AiroTemporaryMobileServerCapability.autoShutdownOnExpiry,
      AiroTemporaryMobileServerCapability.idleShutdown,
    },
  });

  final int minBatteryPercent;
  final AiroTemporaryMobileThermalState maxAllowedThermalState;
  final int maxConcurrentReceivers;
  final Set<AiroRouteAccessScope> requiredAccessScopes;
  final Set<AiroTemporaryMobileServerCapability> requiredCapabilities;

  AiroTemporaryMobileServerValidationResult validate({
    required AiroTemporaryMobileServerSnapshot snapshot,
    required AiroTemporaryMobileServerValidationContext context,
  }) {
    final codes = <AiroTemporaryMobileServerValidationCode>[];
    if (snapshot.isExpired(context.now)) {
      codes.add(AiroTemporaryMobileServerValidationCode.expired);
    }
    if (snapshot.isIdleTimedOut(context.now)) {
      codes.add(AiroTemporaryMobileServerValidationCode.idleTimeoutExceeded);
    }
    if (!context.hasLocalNetworkScope ||
        !snapshot.supports(AiroTemporaryMobileServerCapability.lanOnly)) {
      codes.add(AiroTemporaryMobileServerValidationCode.localNetworkRequired);
    }
    if (snapshot.requiresTrustedReceiverScope &&
        !context.hasTrustedReceiverScope) {
      codes.add(
        AiroTemporaryMobileServerValidationCode.trustedReceiverRequired,
      );
    }
    if (!snapshot.allowsReceiver(context.receiverNodeId)) {
      codes.add(AiroTemporaryMobileServerValidationCode.receiverNotAllowed);
    }
    if (!snapshot.accessGrant.isBoundTo(context.receiverNodeId)) {
      codes.add(AiroTemporaryMobileServerValidationCode.grantAudienceMismatch);
    }
    if (snapshot.accessGrant.isExpired(context.now)) {
      codes.add(AiroTemporaryMobileServerValidationCode.grantExpired);
    }
    if (!snapshot.accessGrant.allowsAll(requiredAccessScopes)) {
      codes.add(AiroTemporaryMobileServerValidationCode.grantScopeMissing);
    }
    _addCapabilityBlockers(snapshot, codes);
    if (!snapshot.isCharging && snapshot.batteryPercent < minBatteryPercent) {
      codes.add(AiroTemporaryMobileServerValidationCode.batteryTooLow);
    }
    if (snapshot.thermalState.index > maxAllowedThermalState.index) {
      codes.add(AiroTemporaryMobileServerValidationCode.thermalTooHigh);
    }
    if (snapshot.activeReceiverCount > maxConcurrentReceivers) {
      codes.add(
        AiroTemporaryMobileServerValidationCode.concurrentReceiverLimitExceeded,
      );
    }

    return AiroTemporaryMobileServerValidationResult(
      serverId: snapshot.serverId,
      codes: codes.isEmpty
          ? const [AiroTemporaryMobileServerValidationCode.accepted]
          : codes,
    );
  }

  void _addCapabilityBlockers(
    AiroTemporaryMobileServerSnapshot snapshot,
    List<AiroTemporaryMobileServerValidationCode> codes,
  ) {
    if (requiredCapabilities.contains(
          AiroTemporaryMobileServerCapability.rangeRequests,
        ) &&
        !snapshot.supports(AiroTemporaryMobileServerCapability.rangeRequests)) {
      codes.add(AiroTemporaryMobileServerValidationCode.rangeRequestsRequired);
    }
    if (requiredCapabilities.contains(
          AiroTemporaryMobileServerCapability.probeRequests,
        ) &&
        !snapshot.supports(AiroTemporaryMobileServerCapability.probeRequests)) {
      codes.add(AiroTemporaryMobileServerValidationCode.probeRequestsRequired);
    }
    if (requiredCapabilities.contains(
          AiroTemporaryMobileServerCapability.entityValidation,
        ) &&
        !snapshot.supports(
          AiroTemporaryMobileServerCapability.entityValidation,
        )) {
      codes.add(
        AiroTemporaryMobileServerValidationCode.entityValidationRequired,
      );
    }
    if (requiredCapabilities.contains(
          AiroTemporaryMobileServerCapability.autoShutdownOnExpiry,
        ) &&
        !snapshot.supports(
          AiroTemporaryMobileServerCapability.autoShutdownOnExpiry,
        )) {
      codes.add(AiroTemporaryMobileServerValidationCode.autoShutdownRequired);
    }
    if (requiredCapabilities.contains(
          AiroTemporaryMobileServerCapability.idleShutdown,
        ) &&
        !snapshot.supports(AiroTemporaryMobileServerCapability.idleShutdown)) {
      codes.add(AiroTemporaryMobileServerValidationCode.idleShutdownRequired);
    }
  }
}

abstract interface class AiroTemporaryMobileServerController {
  FutureOr<AiroTemporaryMobileServerSnapshot?> currentSnapshot();

  FutureOr<AiroTemporaryMobileServerValidationResult> validate(
    AiroTemporaryMobileServerValidationContext context,
  );

  FutureOr<AiroTemporaryMobileServerServingDecision> evaluateServing(
    AiroTemporaryMobileServerServingRequest request,
  );

  FutureOr<void> shutdown(String serverId);
}

class AiroNoOpTemporaryMobileServerController
    implements AiroTemporaryMobileServerController {
  const AiroNoOpTemporaryMobileServerController();

  @override
  FutureOr<AiroTemporaryMobileServerSnapshot?> currentSnapshot() => null;

  @override
  FutureOr<AiroTemporaryMobileServerValidationResult> validate(
    AiroTemporaryMobileServerValidationContext context,
  ) {
    return AiroTemporaryMobileServerValidationResult(
      serverId: 'none',
      codes: const [AiroTemporaryMobileServerValidationCode.serverUnavailable],
    );
  }

  @override
  FutureOr<AiroTemporaryMobileServerServingDecision> evaluateServing(
    AiroTemporaryMobileServerServingRequest request,
  ) {
    return AiroTemporaryMobileServerServingDecision(
      serverId: 'none',
      requestId: request.requestId,
      status: AiroTemporaryMobileServerServingStatus.reject,
      validationCodes: const [
        AiroTemporaryMobileServerValidationCode.serverUnavailable,
      ],
      servingCodes: const [],
      responseHeaders: const {},
    );
  }

  @override
  FutureOr<void> shutdown(String serverId) {}
}

class AiroFakeTemporaryMobileServerController
    implements AiroTemporaryMobileServerController {
  AiroFakeTemporaryMobileServerController({
    this.snapshot,
    this.policy = const AiroTemporaryMobileServerPolicy(),
    this.servingPolicy = const AiroTemporaryMobileServerServingPolicy(),
  });

  AiroTemporaryMobileServerSnapshot? snapshot;
  final AiroTemporaryMobileServerPolicy policy;
  final AiroTemporaryMobileServerServingPolicy servingPolicy;
  int shutdownCallCount = 0;

  @override
  FutureOr<AiroTemporaryMobileServerSnapshot?> currentSnapshot() => snapshot;

  @override
  FutureOr<AiroTemporaryMobileServerValidationResult> validate(
    AiroTemporaryMobileServerValidationContext context,
  ) {
    final current = snapshot;
    if (current == null) {
      return AiroTemporaryMobileServerValidationResult(
        serverId: 'none',
        codes: const [
          AiroTemporaryMobileServerValidationCode.serverUnavailable,
        ],
      );
    }
    return policy.validate(snapshot: current, context: context);
  }

  @override
  FutureOr<AiroTemporaryMobileServerServingDecision> evaluateServing(
    AiroTemporaryMobileServerServingRequest request,
  ) {
    final current = snapshot;
    if (current == null) {
      return AiroTemporaryMobileServerServingDecision(
        serverId: 'none',
        requestId: request.requestId,
        status: AiroTemporaryMobileServerServingStatus.reject,
        validationCodes: const [
          AiroTemporaryMobileServerValidationCode.serverUnavailable,
        ],
        servingCodes: const [],
        responseHeaders: const {},
      );
    }
    return servingPolicy.evaluate(snapshot: current, request: request);
  }

  @override
  FutureOr<void> shutdown(String serverId) {
    shutdownCallCount += 1;
    if (snapshot?.serverId == serverId) {
      snapshot = null;
    }
  }
}

List<String> _validationCodeStableIds(
  Iterable<AiroTemporaryMobileServerValidationCode> values,
) {
  return values.map((value) => value.stableId).toList(growable: false)..sort();
}

List<String> _servingCodeStableIds(
  Iterable<AiroTemporaryMobileServerServingCode> values,
) {
  return values.map((value) => value.stableId).toList(growable: false)..sort();
}
