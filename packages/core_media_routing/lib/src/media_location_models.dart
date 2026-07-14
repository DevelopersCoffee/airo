import 'package:equatable/equatable.dart';

const String kAiroMediaLocationSchemaVersion = '1.0.0';

enum AiroMediaLocationKind {
  publicInternet('public_internet'),
  authenticatedInternet('authenticated_internet'),
  iptvStream('iptv_stream'),
  lanHttp('lan_http'),
  nasShareItem('nas_share_item'),
  mediaServerItem('media_server_item'),
  localFile('local_file'),
  phoneLocalFile('phone_local_file'),
  tvRemovableFile('tv_removable_file'),
  desktopFile('desktop_file'),
  temporaryHttpAccess('temporary_http_access');

  const AiroMediaLocationKind(this.stableId);

  final String stableId;
}

enum AiroMediaLocationLocality {
  internet('internet'),
  localNetwork('local_network'),
  deviceLocal('device_local'),
  removableStorage('removable_storage'),
  relay('relay');

  const AiroMediaLocationLocality(this.stableId);

  final String stableId;
}

enum AiroRouteAccessScope {
  playbackRead('playback_read'),
  rangeRead('range_read'),
  metadataRead('metadata_read'),
  probeRead('probe_read');

  const AiroRouteAccessScope(this.stableId);

  final String stableId;
}

enum AiroRouteAccessHandleRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value');

  const AiroRouteAccessHandleRejectionCode(this.stableId);

  final String stableId;
}

enum AiroMediaLocationValidationCode {
  accepted('accepted'),
  expired('expired'),
  localNetworkScopeMissing('local_network_scope_missing'),
  trustedDeviceScopeMissing('trusted_device_scope_missing'),
  temporaryAccessExpiryMissing('temporary_access_expiry_missing');

  const AiroMediaLocationValidationCode(this.stableId);

  final String stableId;
}

enum AiroRouteAccessGrantValidationCode {
  accepted('accepted'),
  locationExpired('location_expired'),
  grantExpired('grant_expired'),
  wrongAudience('wrong_audience'),
  scopeMissing('scope_missing'),
  trustedDeviceScopeMissing('trusted_device_scope_missing');

  const AiroRouteAccessGrantValidationCode(this.stableId);

  final String stableId;
}

class AiroRouteAccessHandle extends Equatable {
  const AiroRouteAccessHandle._(this.value);

  factory AiroRouteAccessHandle.redacted(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroRouteAccessHandle._(value.trim());
  }

  final String value;

  static AiroRouteAccessHandleRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return AiroRouteAccessHandleRejectionCode.empty;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroRouteAccessHandleRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroRouteAccessHandleRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroRouteAccessHandleRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroRouteAccessHandleRejectionCode.credentialLikeValue;
    }

    return null;
  }

  @override
  String toString() => 'AiroRouteAccessHandle(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroMediaLocation extends Equatable {
  const AiroMediaLocation({
    required this.locationId,
    required this.mediaId,
    required this.kind,
    required this.locality,
    required this.accessHandle,
    this.ownerNodeId,
    this.expiresAt,
    this.requiresLocalNetworkScope = false,
    this.requiresTrustedDeviceScope = false,
    this.supportsRangeRequests = false,
    this.supportsProbeRequests = false,
    this.schemaVersion = kAiroMediaLocationSchemaVersion,
  });

  final String schemaVersion;
  final String locationId;
  final String mediaId;
  final AiroMediaLocationKind kind;
  final AiroMediaLocationLocality locality;
  final AiroRouteAccessHandle accessHandle;
  final String? ownerNodeId;
  final DateTime? expiresAt;
  final bool requiresLocalNetworkScope;
  final bool requiresTrustedDeviceScope;
  final bool supportsRangeRequests;
  final bool supportsProbeRequests;

  bool get isTemporaryAccess =>
      kind == AiroMediaLocationKind.temporaryHttpAccess;

  bool isExpired(DateTime now) =>
      expiresAt != null && !now.isBefore(expiresAt!);

  @override
  String toString() {
    return 'AiroMediaLocation('
        'locationId: $locationId, '
        'mediaId: $mediaId, '
        'kind: ${kind.stableId}, '
        'locality: ${locality.stableId}, '
        'ownerNodeId: $ownerNodeId, '
        'accessHandle: redacted, '
        'expiresAt: $expiresAt'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    locationId,
    mediaId,
    kind,
    locality,
    accessHandle,
    ownerNodeId,
    expiresAt,
    requiresLocalNetworkScope,
    requiresTrustedDeviceScope,
    supportsRangeRequests,
    supportsProbeRequests,
  ];
}

class AiroMediaLocationValidationContext extends Equatable {
  const AiroMediaLocationValidationContext({
    required this.now,
    this.hasLocalNetworkScope = false,
    this.hasTrustedDeviceScope = false,
  });

  final DateTime now;
  final bool hasLocalNetworkScope;
  final bool hasTrustedDeviceScope;

  @override
  List<Object?> get props => [now, hasLocalNetworkScope, hasTrustedDeviceScope];
}

class AiroMediaLocationValidationResult extends Equatable {
  AiroMediaLocationValidationResult({
    required this.locationId,
    required List<AiroMediaLocationValidationCode> codes,
  }) : codes = List.unmodifiable(codes);

  final String locationId;
  final List<AiroMediaLocationValidationCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroMediaLocationValidationCode.accepted;

  @override
  List<Object?> get props => [locationId, codes];
}

class AiroMediaLocationPolicy {
  const AiroMediaLocationPolicy();

  AiroMediaLocationValidationResult validate({
    required AiroMediaLocation location,
    required AiroMediaLocationValidationContext context,
  }) {
    final codes = <AiroMediaLocationValidationCode>[];
    if (location.isExpired(context.now)) {
      codes.add(AiroMediaLocationValidationCode.expired);
    }
    if (location.requiresLocalNetworkScope && !context.hasLocalNetworkScope) {
      codes.add(AiroMediaLocationValidationCode.localNetworkScopeMissing);
    }
    if (location.requiresTrustedDeviceScope && !context.hasTrustedDeviceScope) {
      codes.add(AiroMediaLocationValidationCode.trustedDeviceScopeMissing);
    }
    if (location.isTemporaryAccess && location.expiresAt == null) {
      codes.add(AiroMediaLocationValidationCode.temporaryAccessExpiryMissing);
    }

    return AiroMediaLocationValidationResult(
      locationId: location.locationId,
      codes: codes.isEmpty
          ? const [AiroMediaLocationValidationCode.accepted]
          : codes,
    );
  }
}

class AiroRouteAccessGrant extends Equatable {
  AiroRouteAccessGrant({
    required this.grantId,
    required this.locationId,
    required this.audienceNodeId,
    required this.handle,
    required this.issuedAt,
    required this.expiresAt,
    required Set<AiroRouteAccessScope> scopes,
    this.requiresTrustedDeviceScope = true,
    this.schemaVersion = kAiroMediaLocationSchemaVersion,
  }) : scopes = Set.unmodifiable(scopes);

  final String schemaVersion;
  final String grantId;
  final String locationId;
  final String audienceNodeId;
  final AiroRouteAccessHandle handle;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final Set<AiroRouteAccessScope> scopes;
  final bool requiresTrustedDeviceScope;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  bool isBoundTo(String nodeId) => audienceNodeId == nodeId;

  bool allowsAll(Set<AiroRouteAccessScope> requiredScopes) =>
      scopes.containsAll(requiredScopes);

  @override
  String toString() {
    return 'AiroRouteAccessGrant('
        'grantId: $grantId, '
        'locationId: $locationId, '
        'audienceNodeId: $audienceNodeId, '
        'scopes: ${scopes.map((scope) => scope.stableId).toList()}, '
        'handle: redacted, '
        'expiresAt: $expiresAt'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    grantId,
    locationId,
    audienceNodeId,
    handle,
    issuedAt,
    expiresAt,
    scopes,
    requiresTrustedDeviceScope,
  ];
}

class AiroRouteAccessGrantValidation extends Equatable {
  AiroRouteAccessGrantValidation({
    required this.grantId,
    required List<AiroRouteAccessGrantValidationCode> codes,
  }) : codes = List.unmodifiable(codes);

  final String grantId;
  final List<AiroRouteAccessGrantValidationCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroRouteAccessGrantValidationCode.accepted;

  @override
  List<Object?> get props => [grantId, codes];
}

class AiroRouteAccessGrantPolicy {
  const AiroRouteAccessGrantPolicy();

  AiroRouteAccessGrantValidation validate({
    required AiroMediaLocation location,
    required AiroRouteAccessGrant grant,
    required String requestedByNodeId,
    required Set<AiroRouteAccessScope> requiredScopes,
    required DateTime now,
    required bool hasTrustedDeviceScope,
  }) {
    final codes = <AiroRouteAccessGrantValidationCode>[];
    if (location.isExpired(now)) {
      codes.add(AiroRouteAccessGrantValidationCode.locationExpired);
    }
    if (grant.isExpired(now)) {
      codes.add(AiroRouteAccessGrantValidationCode.grantExpired);
    }
    if (!grant.isBoundTo(requestedByNodeId)) {
      codes.add(AiroRouteAccessGrantValidationCode.wrongAudience);
    }
    if (!grant.allowsAll(requiredScopes)) {
      codes.add(AiroRouteAccessGrantValidationCode.scopeMissing);
    }
    if (grant.requiresTrustedDeviceScope && !hasTrustedDeviceScope) {
      codes.add(AiroRouteAccessGrantValidationCode.trustedDeviceScopeMissing);
    }

    return AiroRouteAccessGrantValidation(
      grantId: grant.grantId,
      codes: codes.isEmpty
          ? const [AiroRouteAccessGrantValidationCode.accepted]
          : codes,
    );
  }
}
