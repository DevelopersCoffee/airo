import 'package:core_media_routing/core_media_routing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroMediaLocationPolicy', () {
    const policy = AiroMediaLocationPolicy();
    final now = DateTime.utc(2026, 7, 14, 12);

    AiroMediaLocation location({
      required String id,
      required AiroMediaLocationKind kind,
      required AiroMediaLocationLocality locality,
      bool localNetwork = false,
      bool trusted = false,
      DateTime? expiresAt,
    }) {
      return AiroMediaLocation(
        locationId: id,
        mediaId: 'media-1',
        kind: kind,
        locality: locality,
        accessHandle: AiroRouteAccessHandle.redacted('location-$id'),
        ownerNodeId: 'owner-1',
        expiresAt: expiresAt,
        requiresLocalNetworkScope: localNetwork,
        requiresTrustedDeviceScope: trusted,
        supportsRangeRequests: true,
        supportsProbeRequests: true,
      );
    }

    test('accepts public IPTV location without exposing source value', () {
      final publicLocation = location(
        id: 'iptv',
        kind: AiroMediaLocationKind.iptvStream,
        locality: AiroMediaLocationLocality.internet,
      );

      final result = policy.validate(
        location: publicLocation,
        context: AiroMediaLocationValidationContext(now: now),
      );

      expect(result.accepted, isTrue);
      expect(publicLocation.toString(), isNot(contains('location-iptv')));
      expect(publicLocation.toString(), contains('accessHandle: redacted'));
    });

    test('LAN and NAS locations require local network scope', () {
      final nasLocation = location(
        id: 'nas',
        kind: AiroMediaLocationKind.nasShareItem,
        locality: AiroMediaLocationLocality.localNetwork,
        localNetwork: true,
      );

      final rejected = policy.validate(
        location: nasLocation,
        context: AiroMediaLocationValidationContext(now: now),
      );
      final accepted = policy.validate(
        location: nasLocation,
        context: AiroMediaLocationValidationContext(
          now: now,
          hasLocalNetworkScope: true,
        ),
      );

      expect(
        rejected.codes,
        contains(AiroMediaLocationValidationCode.localNetworkScopeMissing),
      );
      expect(accepted.accepted, isTrue);
    });

    test('temporary phone access requires trust scope and expiry', () {
      final missingExpiry = location(
        id: 'phone',
        kind: AiroMediaLocationKind.temporaryHttpAccess,
        locality: AiroMediaLocationLocality.relay,
        trusted: true,
      );
      final validTemporary = location(
        id: 'phone-expiring',
        kind: AiroMediaLocationKind.temporaryHttpAccess,
        locality: AiroMediaLocationLocality.relay,
        trusted: true,
        expiresAt: now.add(const Duration(minutes: 5)),
      );

      final rejected = policy.validate(
        location: missingExpiry,
        context: AiroMediaLocationValidationContext(now: now),
      );
      final accepted = policy.validate(
        location: validTemporary,
        context: AiroMediaLocationValidationContext(
          now: now,
          hasTrustedDeviceScope: true,
        ),
      );

      expect(
        rejected.codes,
        contains(AiroMediaLocationValidationCode.temporaryAccessExpiryMissing),
      );
      expect(
        rejected.codes,
        contains(AiroMediaLocationValidationCode.trustedDeviceScopeMissing),
      );
      expect(accepted.accepted, isTrue);
    });

    test('expired locations are rejected', () {
      final expired = location(
        id: 'expired',
        kind: AiroMediaLocationKind.authenticatedInternet,
        locality: AiroMediaLocationLocality.internet,
        expiresAt: now,
      );

      final result = policy.validate(
        location: expired,
        context: AiroMediaLocationValidationContext(now: now),
      );

      expect(result.accepted, isFalse);
      expect(result.codes, contains(AiroMediaLocationValidationCode.expired));
    });
  });

  group('AiroRouteAccessGrantPolicy', () {
    const policy = AiroRouteAccessGrantPolicy();
    final now = DateTime.utc(2026, 7, 14, 12);

    final location = AiroMediaLocation(
      locationId: 'location-1',
      mediaId: 'media-1',
      kind: AiroMediaLocationKind.temporaryHttpAccess,
      locality: AiroMediaLocationLocality.relay,
      accessHandle: AiroRouteAccessHandle.redacted('location-handle'),
      ownerNodeId: 'phone-1',
      expiresAt: now.add(const Duration(minutes: 5)),
      requiresTrustedDeviceScope: true,
      supportsRangeRequests: true,
      supportsProbeRequests: true,
    );

    AiroRouteAccessGrant grant({
      String audienceNodeId = 'receiver-1',
      Set<AiroRouteAccessScope> scopes = const {
        AiroRouteAccessScope.playbackRead,
        AiroRouteAccessScope.rangeRead,
      },
      DateTime? expiresAt,
    }) {
      return AiroRouteAccessGrant(
        grantId: 'grant-1',
        locationId: location.locationId,
        audienceNodeId: audienceNodeId,
        handle: AiroRouteAccessHandle.redacted('grant-handle'),
        issuedAt: now,
        expiresAt: expiresAt ?? now.add(const Duration(minutes: 3)),
        scopes: scopes,
      );
    }

    test('accepts receiver-bound grant with required scopes', () {
      final accessGrant = grant();

      final result = policy.validate(
        location: location,
        grant: accessGrant,
        requestedByNodeId: 'receiver-1',
        requiredScopes: const {
          AiroRouteAccessScope.playbackRead,
          AiroRouteAccessScope.rangeRead,
        },
        now: now,
        hasTrustedDeviceScope: true,
      );

      expect(result.accepted, isTrue);
      expect(accessGrant.toString(), isNot(contains('grant-handle')));
      expect(accessGrant.toString(), contains('handle: redacted'));
    });

    test('rejects expired wrong-audience or underscoped grants', () {
      final expired = grant(expiresAt: now);
      final wrongAudience = grant(audienceNodeId: 'receiver-2');
      final underscoped = grant(
        scopes: const {AiroRouteAccessScope.playbackRead},
      );

      final expiredResult = policy.validate(
        location: location,
        grant: expired,
        requestedByNodeId: 'receiver-1',
        requiredScopes: const {AiroRouteAccessScope.playbackRead},
        now: now,
        hasTrustedDeviceScope: true,
      );
      final audienceResult = policy.validate(
        location: location,
        grant: wrongAudience,
        requestedByNodeId: 'receiver-1',
        requiredScopes: const {AiroRouteAccessScope.playbackRead},
        now: now,
        hasTrustedDeviceScope: true,
      );
      final scopeResult = policy.validate(
        location: location,
        grant: underscoped,
        requestedByNodeId: 'receiver-1',
        requiredScopes: const {
          AiroRouteAccessScope.playbackRead,
          AiroRouteAccessScope.rangeRead,
        },
        now: now,
        hasTrustedDeviceScope: true,
      );

      expect(
        expiredResult.codes,
        contains(AiroRouteAccessGrantValidationCode.grantExpired),
      );
      expect(
        audienceResult.codes,
        contains(AiroRouteAccessGrantValidationCode.wrongAudience),
      );
      expect(
        scopeResult.codes,
        contains(AiroRouteAccessGrantValidationCode.scopeMissing),
      );
    });

    test('requires trusted-device scope for protected grants', () {
      final result = policy.validate(
        location: location,
        grant: grant(),
        requestedByNodeId: 'receiver-1',
        requiredScopes: const {AiroRouteAccessScope.playbackRead},
        now: now,
        hasTrustedDeviceScope: false,
      );

      expect(
        result.codes,
        contains(AiroRouteAccessGrantValidationCode.trustedDeviceScopeMissing),
      );
    });
  });

  group('AiroRouteAccessHandle', () {
    test('rejects raw source values at the boundary', () {
      expect(
        AiroRouteAccessHandle.validate('https://example.com/live.m3u8'),
        AiroRouteAccessHandleRejectionCode.urlValue,
      );
      expect(
        AiroRouteAccessHandle.validate('/Users/me/movie.ts'),
        AiroRouteAccessHandleRejectionCode.localPathValue,
      );
      expect(
        AiroRouteAccessHandle.validate('http://10.0.0.4/live'),
        AiroRouteAccessHandleRejectionCode.urlValue,
      );
      expect(
        AiroRouteAccessHandle.validate('Basic abc123'),
        AiroRouteAccessHandleRejectionCode.credentialLikeValue,
      );
    });
  });
}
