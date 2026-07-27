import 'dart:async';

import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/filter_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mobile Settings' country-filter tile (CV item 3): shows the user's
/// default channel country and opens a picker built from whatever countries
/// their loaded channels actually have. IPTV-module concern — moved out of
/// `app/lib/features/settings` alongside `PlaybackSettingsScreen`, following
/// the same module-ownership rule (see docs/wiki/3.-Navigating-Airo.md).
class CountrySettingsTile extends ConsumerWidget {
  const CountrySettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(channelFiltersProvider);
    final channelsAsync = ref.watch(iptvChannelsProvider);
    final channels = channelsAsync.value ?? const <IPTVChannel>[];
    final dimensions = channelFilterDimensions(
      channels: channels,
      metadataByChannelId: const {},
    );
    final countries = ref.watch(iptvOrgCountryByCodeProvider);
    String countryLabel(String? value) => countryDisplayLabel(
      value,
      taxonomyNames: {
        for (final entry in countries.entries) entry.key: entry.value.name,
      },
      taxonomyFlags: {
        for (final entry in countries.entries) entry.key: entry.value.flag,
      },
    );
    final canPickCountry =
        dimensions.countries.isNotEmpty || filters.country != null;

    final country = iptvSettingsSections.firstWhere(
      (section) => section.id == IptvSettingsSectionId.country,
    );
    return ListTile(
      leading: Icon(country.iconFor(ShellId.mobile)),
      title: Text(country.labelFor(ShellId.mobile)),
      subtitle: Text(
        filters.country != null
            ? countryLabel(filters.country)
            : channelsAsync.isLoading
            ? 'Loading countries…'
            : dimensions.countries.isEmpty
            ? 'Load channels first to choose a country'
            : 'Choose your default channel country',
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      enabled: canPickCountry,
      onTap: !canPickCountry
          ? null
          : () => _showCountryPicker(
              context,
              ref,
              dimensions,
              filters.country,
              countryLabel,
            ),
    );
  }

  Future<void> _showCountryPicker(
    BuildContext context,
    WidgetRef ref,
    ChannelFilterDimensions dimensions,
    String? selectedCountry,
    String Function(String?) countryLabel,
  ) {
    final filters = ref.read(channelFiltersProvider.notifier);
    final countryPrompt = ref.read(channelCountryPromptProvider.notifier);
    return showFilterOptionDialog(
      context: context,
      title: 'Country',
      options: dimensions.countries.toList(growable: false),
      selectedValue: selectedCountry,
      onSelected: (country) {
        filters.setCountry(country);
        unawaited(countryPrompt.markCompleted());
      },
      onClear: () {
        filters.setCountry(null);
        unawaited(countryPrompt.markCompleted());
      },
      optionLabel: countryLabel,
    );
  }
}
