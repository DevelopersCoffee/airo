import 'dart:async';

import 'package:equatable/equatable.dart';

import 'connected_node_models.dart';

const String kAiroEdgeMediaNodeSchemaVersion = '1.0.0';

enum AiroEdgeMediaNodeService {
  mediaIndexing('media_indexing'),
  metadataEnrichment('metadata_enrichment'),
  streamHealth('stream_health'),
  relay('relay'),
  recording('recording'),
  transcoding('transcoding'),
  aiProcessing('ai_processing'),
  artworkProcessing('artwork_processing');

  const AiroEdgeMediaNodeService(this.stableId);

  final String stableId;
}

enum AiroEdgeMediaNodeServiceState {
  placeholder('placeholder'),
  planned('planned'),
  available('available'),
  disabled('disabled'),
  unavailable('unavailable');

  const AiroEdgeMediaNodeServiceState(this.stableId);

  final String stableId;

  bool get executable => this == available;
}

enum AiroEdgeMediaNodeBlockerCode {
  accepted('accepted'),
  schemaMismatch('schema_mismatch'),
  staleAdvertisement('stale_advertisement'),
  incompatibleRole('incompatible_role'),
  lifecycleUnavailable('lifecycle_unavailable'),
  untrustedNode('untrusted_node'),
  blockedNode('blocked_node'),
  missingConnectedNodeCapability('missing_connected_node_capability'),
  serviceMissing('service_missing'),
  serviceNotExecutable('service_not_executable'),
  localNetworkRequired('local_network_required'),
  relayNotAllowed('relay_not_allowed'),
  recordingNotAllowed('recording_not_allowed'),
  transcodingNotAllowed('transcoding_not_allowed');

  const AiroEdgeMediaNodeBlockerCode(this.stableId);

  final String stableId;
}

class AiroEdgeMediaNodeServiceDescriptor extends Equatable {
  const AiroEdgeMediaNodeServiceDescriptor({
    required this.service,
    required this.state,
    this.requiresTrustedNode = true,
    this.requiresLocalNetworkScope = true,
    this.schemaVersion = kAiroEdgeMediaNodeSchemaVersion,
  });

  final String schemaVersion;
  final AiroEdgeMediaNodeService service;
  final AiroEdgeMediaNodeServiceState state;
  final bool requiresTrustedNode;
  final bool requiresLocalNetworkScope;

  bool get executable => state.executable;

  @override
  String toString() {
    return 'AiroEdgeMediaNodeServiceDescriptor('
        'service: ${service.stableId}, '
        'state: ${state.stableId}, '
        'requiresTrustedNode: $requiresTrustedNode, '
        'requiresLocalNetworkScope: $requiresLocalNetworkScope'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    service,
    state,
    requiresTrustedNode,
    requiresLocalNetworkScope,
  ];
}

class AiroEdgeMediaNodeProfile extends Equatable {
  AiroEdgeMediaNodeProfile({
    required this.profileId,
    required this.advertisement,
    required List<AiroEdgeMediaNodeServiceDescriptor> services,
    required this.observedAt,
    this.schemaVersion = kAiroEdgeMediaNodeSchemaVersion,
  }) : services = List.unmodifiable(services);

  final String schemaVersion;
  final String profileId;
  final AiroNodeCapabilityAdvertisement advertisement;
  final List<AiroEdgeMediaNodeServiceDescriptor> services;
  final DateTime observedAt;

  String get nodeId => advertisement.identity.nodeId;

  AiroEdgeMediaNodeServiceDescriptor? descriptorFor(
    AiroEdgeMediaNodeService service,
  ) {
    for (final descriptor in services) {
      if (descriptor.service == service) return descriptor;
    }
    return null;
  }

  @override
  String toString() {
    return 'AiroEdgeMediaNodeProfile('
        'profileId: $profileId, '
        'nodeId: $nodeId, '
        'role: ${advertisement.identity.role.stableId}, '
        'platformCategory: ${advertisement.identity.platformCategory.stableId}, '
        'services: ${services.map((service) => '${service.service.stableId}:${service.state.stableId}').toList()}'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    profileId,
    advertisement,
    services,
    observedAt,
  ];
}

class AiroEdgeMediaNodeRequest extends Equatable {
  const AiroEdgeMediaNodeRequest({
    required this.requestId,
    required this.requestedByNodeId,
    required this.service,
    this.hasLocalNetworkScope = false,
    this.allowRelay = false,
    this.allowRecording = false,
    this.allowTranscoding = false,
    this.schemaVersion = kAiroEdgeMediaNodeSchemaVersion,
  });

  final String schemaVersion;
  final String requestId;
  final String requestedByNodeId;
  final AiroEdgeMediaNodeService service;
  final bool hasLocalNetworkScope;
  final bool allowRelay;
  final bool allowRecording;
  final bool allowTranscoding;

  @override
  List<Object?> get props => [
    schemaVersion,
    requestId,
    requestedByNodeId,
    service,
    hasLocalNetworkScope,
    allowRelay,
    allowRecording,
    allowTranscoding,
  ];
}

class AiroEdgeMediaNodeEvaluation extends Equatable {
  AiroEdgeMediaNodeEvaluation({
    required this.nodeId,
    required this.requestId,
    required List<AiroEdgeMediaNodeBlockerCode> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final String nodeId;
  final String requestId;
  final List<AiroEdgeMediaNodeBlockerCode> blockers;

  bool get accepted =>
      blockers.length == 1 &&
      blockers.single == AiroEdgeMediaNodeBlockerCode.accepted;

  @override
  List<Object?> get props => [nodeId, requestId, blockers];
}

class AiroEdgeMediaNodePolicy {
  const AiroEdgeMediaNodePolicy();

  AiroEdgeMediaNodeEvaluation evaluate({
    required AiroEdgeMediaNodeProfile profile,
    required AiroEdgeMediaNodeRequest request,
    required DateTime now,
  }) {
    final blockers = <AiroEdgeMediaNodeBlockerCode>[];
    final advertisement = profile.advertisement;
    final descriptor = profile.descriptorFor(request.service);

    if (profile.schemaVersion != kAiroEdgeMediaNodeSchemaVersion) {
      blockers.add(AiroEdgeMediaNodeBlockerCode.schemaMismatch);
    }
    if (advertisement.isExpired(now)) {
      blockers.add(AiroEdgeMediaNodeBlockerCode.staleAdvertisement);
    }
    if (!_isEdgeNodeRole(advertisement.identity.role)) {
      blockers.add(AiroEdgeMediaNodeBlockerCode.incompatibleRole);
    }
    if (advertisement.lifecycle == AiroNodeLifecycleState.blocked ||
        advertisement.trustState == AiroNodeTrustState.revoked) {
      blockers.add(AiroEdgeMediaNodeBlockerCode.blockedNode);
    } else if (!advertisement.lifecycle.canNegotiate) {
      blockers.add(AiroEdgeMediaNodeBlockerCode.lifecycleUnavailable);
    }
    if (!advertisement.trustState.allowsPrivateCompatibility) {
      blockers.add(AiroEdgeMediaNodeBlockerCode.untrustedNode);
    }
    _addCapabilityBlockers(advertisement, request, blockers);
    _addServiceBlockers(descriptor, request, blockers);

    return AiroEdgeMediaNodeEvaluation(
      nodeId: profile.nodeId,
      requestId: request.requestId,
      blockers: blockers.isEmpty
          ? const [AiroEdgeMediaNodeBlockerCode.accepted]
          : blockers,
    );
  }

  bool _isEdgeNodeRole(AiroNodeRole role) {
    return role == AiroNodeRole.homeNode ||
        role == AiroNodeRole.desktopCompanion;
  }

  void _addCapabilityBlockers(
    AiroNodeCapabilityAdvertisement advertisement,
    AiroEdgeMediaNodeRequest request,
    List<AiroEdgeMediaNodeBlockerCode> blockers,
  ) {
    final requiredCapability = _requiredConnectedNodeCapability(
      request.service,
    );
    if (requiredCapability != null &&
        !advertisement.advertises(requiredCapability)) {
      blockers.add(AiroEdgeMediaNodeBlockerCode.missingConnectedNodeCapability);
    }
  }

  AiroNodeCapability? _requiredConnectedNodeCapability(
    AiroEdgeMediaNodeService service,
  ) {
    switch (service) {
      case AiroEdgeMediaNodeService.mediaIndexing:
        return AiroNodeCapability.mediaIndexing;
      case AiroEdgeMediaNodeService.metadataEnrichment:
        return AiroNodeCapability.metadataProcessing;
      case AiroEdgeMediaNodeService.streamHealth:
        return AiroNodeCapability.diagnostics;
      case AiroEdgeMediaNodeService.relay:
        return AiroNodeCapability.commandRouting;
      case AiroEdgeMediaNodeService.recording:
        return AiroNodeCapability.recording;
      case AiroEdgeMediaNodeService.transcoding:
        return AiroNodeCapability.transcoding;
      case AiroEdgeMediaNodeService.aiProcessing:
        return AiroNodeCapability.aiDelegation;
      case AiroEdgeMediaNodeService.artworkProcessing:
        return AiroNodeCapability.metadataProcessing;
    }
  }

  void _addServiceBlockers(
    AiroEdgeMediaNodeServiceDescriptor? descriptor,
    AiroEdgeMediaNodeRequest request,
    List<AiroEdgeMediaNodeBlockerCode> blockers,
  ) {
    if (descriptor == null) {
      blockers.add(AiroEdgeMediaNodeBlockerCode.serviceMissing);
      return;
    }
    if (!descriptor.executable) {
      blockers.add(AiroEdgeMediaNodeBlockerCode.serviceNotExecutable);
    }
    if (descriptor.requiresLocalNetworkScope && !request.hasLocalNetworkScope) {
      blockers.add(AiroEdgeMediaNodeBlockerCode.localNetworkRequired);
    }
    switch (request.service) {
      case AiroEdgeMediaNodeService.relay:
        if (!request.allowRelay) {
          blockers.add(AiroEdgeMediaNodeBlockerCode.relayNotAllowed);
        }
      case AiroEdgeMediaNodeService.recording:
        if (!request.allowRecording) {
          blockers.add(AiroEdgeMediaNodeBlockerCode.recordingNotAllowed);
        }
      case AiroEdgeMediaNodeService.transcoding:
        if (!request.allowTranscoding) {
          blockers.add(AiroEdgeMediaNodeBlockerCode.transcodingNotAllowed);
        }
      case AiroEdgeMediaNodeService.mediaIndexing:
      case AiroEdgeMediaNodeService.metadataEnrichment:
      case AiroEdgeMediaNodeService.streamHealth:
      case AiroEdgeMediaNodeService.aiProcessing:
      case AiroEdgeMediaNodeService.artworkProcessing:
        break;
    }
  }
}

abstract interface class AiroEdgeMediaNodeRegistry {
  FutureOr<List<AiroEdgeMediaNodeProfile>> candidates();
}

class AiroNoOpEdgeMediaNodeRegistry implements AiroEdgeMediaNodeRegistry {
  const AiroNoOpEdgeMediaNodeRegistry();

  @override
  FutureOr<List<AiroEdgeMediaNodeProfile>> candidates() => const [];
}

class AiroFakeEdgeMediaNodeRegistry implements AiroEdgeMediaNodeRegistry {
  AiroFakeEdgeMediaNodeRegistry({
    required List<AiroEdgeMediaNodeProfile> profiles,
  }) : profiles = List.unmodifiable(profiles);

  final List<AiroEdgeMediaNodeProfile> profiles;

  @override
  FutureOr<List<AiroEdgeMediaNodeProfile>> candidates() => profiles;
}
