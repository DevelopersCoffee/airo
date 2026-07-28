import 'package:core_entitlements/core_entitlements.dart';
import 'package:equatable/equatable.dart';

import 'sports_desk_models.dart';

enum ProviderLicenseDecision { pending, approved, rejected }

final class RicherContextAttribution extends Equatable {
  const RicherContextAttribution({
    required this.providerId,
    required this.providerName,
    required this.notice,
    required this.url,
    this.logoAsset,
  });

  final String providerId;
  final String providerName;
  final String notice;
  final Uri url;
  final String? logoAsset;

  @override
  List<Object?> get props => [providerId, providerName, notice, url, logoAsset];
}

final class RicherContextProviderDescriptor extends Equatable {
  const RicherContextProviderDescriptor({
    required this.id,
    required this.name,
    required this.licenseDecision,
    required this.licenseReviewedAt,
    required this.attribution,
  });

  final String id;
  final String name;
  final ProviderLicenseDecision licenseDecision;
  final DateTime licenseReviewedAt;
  final RicherContextAttribution attribution;

  @override
  List<Object?> get props => [
    id,
    name,
    licenseDecision,
    licenseReviewedAt,
    attribution,
  ];
}

final class ProgrammeMetadataRequest extends Equatable {
  const ProgrammeMetadataRequest({
    required this.title,
    required this.startsAt,
    this.languageCode,
  });

  final String title;
  final DateTime startsAt;
  final String? languageCode;

  @override
  List<Object?> get props => [title, startsAt, languageCode];
}

final class ProgrammeEnrichment extends Equatable {
  const ProgrammeEnrichment({
    required this.providerItemId,
    required this.title,
    required this.synopsis,
    required this.attribution,
    this.posterUrl,
    this.year,
    this.rating,
    this.genres = const [],
  });

  final String providerItemId;
  final String title;
  final String synopsis;
  final Uri? posterUrl;
  final int? year;
  final double? rating;
  final List<String> genres;
  final RicherContextAttribution attribution;

  @override
  List<Object?> get props => [
    providerItemId,
    title,
    synopsis,
    posterUrl,
    year,
    rating,
    genres,
    attribution,
  ];
}

final class SportsFixturesRequest extends Equatable {
  const SportsFixturesRequest({
    required this.channelId,
    required this.isSportsChannel,
    required this.from,
    required this.to,
    this.countryCode,
  });

  final String channelId;
  final bool isSportsChannel;
  final DateTime from;
  final DateTime to;
  final String? countryCode;

  @override
  List<Object?> get props => [
    channelId,
    isSportsChannel,
    from,
    to,
    countryCode,
  ];
}

final class AttributedSportsDeskRow extends Equatable {
  const AttributedSportsDeskRow({required this.row, required this.attribution});

  final SportsDeskRow row;
  final RicherContextAttribution attribution;

  @override
  List<Object?> get props => [row, attribution];
}

/// Provider adapter implemented by the private overlay.
abstract interface class RicherContextProvider {
  RicherContextProviderDescriptor get descriptor;

  Future<ProgrammeEnrichment?> enrichProgramme(
    ProgrammeMetadataRequest request,
  );

  Future<AttributedSportsDeskRow?> fetchSportsFixtures(
    SportsFixturesRequest request,
  );
}

final class RicherContextConsent extends Equatable {
  const RicherContextConsent({
    required this.providerId,
    this.metadataEnabled = false,
    this.sportsEnabled = false,
  });

  final String providerId;
  final bool metadataEnabled;
  final bool sportsEnabled;

  @override
  List<Object?> get props => [providerId, metadataEnabled, sportsEnabled];
}

/// Enforces entitlement, license, and explicit provider consent before an
/// injected adapter can perform any network-capable operation.
final class RicherContextCoordinator {
  const RicherContextCoordinator({
    required this.entitlements,
    required this.provider,
    required this.consent,
  });

  final Entitlements entitlements;
  final RicherContextProvider? provider;
  final RicherContextConsent consent;

  Future<ProgrammeEnrichment?> enrichProgramme(
    ProgrammeMetadataRequest request,
  ) async {
    final adapter = provider;
    if (!_canUse(
      adapter,
      ProFeature.metadataEnrichment,
      consent.metadataEnabled,
    )) {
      return null;
    }
    try {
      final result = await adapter!.enrichProgramme(request);
      return _hasValidAttribution(result?.attribution, adapter) ? result : null;
    } on Object {
      return null;
    }
  }

  Future<AttributedSportsDeskRow?> fetchSportsFixtures(
    SportsFixturesRequest request,
  ) async {
    final adapter = provider;
    if (!request.isSportsChannel ||
        !_canUse(adapter, ProFeature.sportsDesk, consent.sportsEnabled)) {
      return null;
    }
    try {
      final result = await adapter!.fetchSportsFixtures(request);
      return _hasValidAttribution(result?.attribution, adapter) ? result : null;
    } on Object {
      return null;
    }
  }

  bool _canUse(
    RicherContextProvider? adapter,
    ProFeature feature,
    bool consentEnabled,
  ) {
    if (adapter == null ||
        !entitlements.isEnabled(feature) ||
        !consentEnabled ||
        consent.providerId != adapter.descriptor.id) {
      return false;
    }
    return adapter.descriptor.licenseDecision ==
        ProviderLicenseDecision.approved;
  }

  bool _hasValidAttribution(
    RicherContextAttribution? attribution,
    RicherContextProvider adapter,
  ) {
    return attribution != null &&
        attribution == adapter.descriptor.attribution &&
        attribution.notice.trim().isNotEmpty &&
        attribution.url.hasScheme;
  }
}
