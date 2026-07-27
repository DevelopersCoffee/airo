import 'dart:async';

import 'package:core_entitlements/core_entitlements.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  final attribution = RicherContextAttribution(
    providerId: 'internal-fixture',
    providerName: 'Internal Fixture',
    notice: 'Internal prototype data',
    url: Uri.https('example.invalid', '/attribution'),
  );
  final descriptor = RicherContextProviderDescriptor(
    id: 'internal-fixture',
    name: 'Internal Fixture',
    licenseDecision: ProviderLicenseDecision.approved,
    licenseReviewedAt: DateTime.utc(2026, 7, 27),
    attribution: attribution,
  );

  test('denied entitlement prevents programme adapter invocation', () async {
    final provider = _RecordingProvider(descriptor, attribution);
    final coordinator = RicherContextCoordinator(
      entitlements: const NoEntitlements(),
      provider: provider,
      consent: const RicherContextConsent(
        providerId: 'internal-fixture',
        metadataEnabled: true,
      ),
    );

    expect(await coordinator.enrichProgramme(_programmeRequest), isNull);
    expect(provider.programmeCalls, 0);
  });

  test('missing consent prevents programme adapter invocation', () async {
    final provider = _RecordingProvider(descriptor, attribution);
    final coordinator = RicherContextCoordinator(
      entitlements: const LaunchPromoEntitlements(),
      provider: provider,
      consent: const RicherContextConsent(providerId: 'internal-fixture'),
    );

    expect(await coordinator.enrichProgramme(_programmeRequest), isNull);
    expect(provider.programmeCalls, 0);
  });

  test('approved provider behind both gates enriches programme', () async {
    final provider = _RecordingProvider(descriptor, attribution);
    final coordinator = RicherContextCoordinator(
      entitlements: const LaunchPromoEntitlements(),
      provider: provider,
      consent: const RicherContextConsent(
        providerId: 'internal-fixture',
        metadataEnabled: true,
      ),
    );

    final result = await coordinator.enrichProgramme(_programmeRequest);

    expect(result?.synopsis, 'A licensed internal prototype synopsis.');
    expect(result?.attribution, attribution);
    expect(provider.programmeCalls, 1);
  });

  test(
    'pending license blocks calls even with entitlement and consent',
    () async {
      final provider = _RecordingProvider(
        RicherContextProviderDescriptor(
          id: descriptor.id,
          name: descriptor.name,
          licenseDecision: ProviderLicenseDecision.pending,
          licenseReviewedAt: descriptor.licenseReviewedAt,
          attribution: attribution,
        ),
        attribution,
      );
      final coordinator = RicherContextCoordinator(
        entitlements: const LaunchPromoEntitlements(),
        provider: provider,
        consent: const RicherContextConsent(
          providerId: 'internal-fixture',
          metadataEnabled: true,
        ),
      );

      expect(await coordinator.enrichProgramme(_programmeRequest), isNull);
      expect(provider.programmeCalls, 0);
    },
  );

  test('sports prototype invokes adapter only for sports channels', () async {
    final provider = _RecordingProvider(descriptor, attribution);
    final coordinator = RicherContextCoordinator(
      entitlements: const LaunchPromoEntitlements(),
      provider: provider,
      consent: const RicherContextConsent(
        providerId: 'internal-fixture',
        sportsEnabled: true,
      ),
    );

    expect(
      await coordinator.fetchSportsFixtures(
        _sportsRequest(isSportsChannel: false),
      ),
      isNull,
    );
    final result = await coordinator.fetchSportsFixtures(
      _sportsRequest(isSportsChannel: true),
    );

    expect(result?.row.fixtures.single.title, 'India vs Australia');
    expect(result?.attribution, attribution);
    expect(provider.sportsCalls, 1);
  });

  test('revoked entitlement fences subsequent provider requests', () async {
    final entitlements = _MutableEntitlements({ProFeature.metadataEnrichment});
    final provider = _RecordingProvider(descriptor, attribution);
    RicherContextCoordinator coordinator() => RicherContextCoordinator(
      entitlements: entitlements,
      provider: provider,
      consent: const RicherContextConsent(
        providerId: 'internal-fixture',
        metadataEnabled: true,
      ),
    );

    expect(await coordinator().enrichProgramme(_programmeRequest), isNotNull);
    entitlements.enabled.clear();
    expect(await coordinator().enrichProgramme(_programmeRequest), isNull);
    expect(provider.programmeCalls, 1);
  });

  test('adapter failure degrades to empty content', () async {
    final provider = _RecordingProvider(
      descriptor,
      attribution,
      shouldThrow: true,
    );
    final coordinator = RicherContextCoordinator(
      entitlements: const LaunchPromoEntitlements(),
      provider: provider,
      consent: const RicherContextConsent(
        providerId: 'internal-fixture',
        metadataEnabled: true,
      ),
    );

    expect(await coordinator.enrichProgramme(_programmeRequest), isNull);
  });
}

final _programmeRequest = ProgrammeMetadataRequest(
  title: 'Example Programme',
  startsAt: DateTime.utc(2026, 7, 27, 12),
  languageCode: 'en',
);

SportsFixturesRequest _sportsRequest({required bool isSportsChannel}) =>
    SportsFixturesRequest(
      channelId: 'sports.in',
      isSportsChannel: isSportsChannel,
      from: DateTime.utc(2026, 7, 27),
      to: DateTime.utc(2026, 7, 28),
      countryCode: 'IN',
    );

final class _RecordingProvider implements RicherContextProvider {
  _RecordingProvider(
    this.descriptor,
    this.attribution, {
    this.shouldThrow = false,
  });

  @override
  final RicherContextProviderDescriptor descriptor;
  final RicherContextAttribution attribution;
  final bool shouldThrow;
  int programmeCalls = 0;
  int sportsCalls = 0;

  @override
  Future<ProgrammeEnrichment?> enrichProgramme(
    ProgrammeMetadataRequest request,
  ) async {
    programmeCalls++;
    if (shouldThrow) throw StateError('prototype failure');
    return ProgrammeEnrichment(
      providerItemId: 'programme-1',
      title: request.title,
      synopsis: 'A licensed internal prototype synopsis.',
      posterUrl: Uri.https('example.invalid', '/poster.jpg'),
      attribution: attribution,
    );
  }

  @override
  Future<AttributedSportsDeskRow?> fetchSportsFixtures(
    SportsFixturesRequest request,
  ) async {
    sportsCalls++;
    return AttributedSportsDeskRow(
      row: SportsDeskRow(
        rowId: 'sports-live',
        title: 'Live now / upcoming',
        fixtures: [
          SportsFixture(
            eventId: 'fixture-1',
            title: 'India vs Australia',
            sport: 'Cricket',
            startsAt: request.from,
          ),
        ],
      ),
      attribution: attribution,
    );
  }
}

final class _MutableEntitlements implements Entitlements {
  _MutableEntitlements(this.enabled);

  final Set<ProFeature> enabled;

  @override
  Stream<Set<ProFeature>> get changes => const Stream.empty();

  @override
  bool isEnabled(ProFeature feature) => enabled.contains(feature);
}
