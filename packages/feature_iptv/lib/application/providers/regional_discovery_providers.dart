import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../domain/regional_discovery.dart';
import 'channel_auto_scan_providers.dart';
import 'channel_filters_provider.dart';
import 'iptv_org_api_providers.dart';
import 'iptv_providers.dart';

/// Host-overridable locale signal. This reads only the device locale and never
/// performs network, IP, GPS, or account-based location inference.
final regionalDiscoveryLocaleProvider = Provider<Locale>(
  (ref) => PlatformDispatcher.instance.locale,
);

/// The existing manual country picker is also the regional preference surface.
/// It already persists locally, so discovery cannot drift from the user's
/// visible filter setting or introduce a second hidden preference.
final regionalDiscoveryCountryProvider = Provider<String>((ref) {
  final manualCountry = ref.watch(channelFiltersProvider).country;
  final localeCountry = ref.watch(regionalDiscoveryLocaleProvider).countryCode;
  return (manualCountry ?? localeCountry ?? 'IN').trim().toUpperCase();
});

final regionalDiscoveryRailsProvider = FutureProvider<List<RailResult>>((
  ref,
) async {
  final channels = await ref.watch(iptvChannelsProvider.future);
  final countryCode = ref.watch(regionalDiscoveryCountryProvider);
  final countries = ref.watch(iptvOrgCountryByCodeProvider);
  final languages = ref.watch(iptvOrgLanguageByCodeProvider);
  final availability = ref
      .watch(channelAutoScanProvider)
      .availabilityByChannelId;
  return const RegionalDiscoveryComposer().compose(
    channels: channels,
    countryCode: countryCode,
    countryName: countries[countryCode]?.name ?? countryCode,
    languageNames: {
      for (final entry in languages.entries) entry.key: entry.value.name,
    },
    availabilityByChannelId: availability,
  );
});
