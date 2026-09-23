import 'dart:async';

import 'package:core_product_shell/core_product_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/filter_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mobile Settings' country-filter tile (CV item 3): shows the user's
/// default channel country and opens a picker built from whatever countries
/// their loaded channels actually have. IPTV-module concern — moved out of
/// `app/lib/features/settings` alongside `PlaybackSettingsScreen`, following
/// the same module-ownership rule (see docs/wiki/3.-Navigating-Airo.md).
///
/// TV (`forTv: true`) uses [TvFocusable] + [showTvLongListPicker]. An empty
/// country list stays focusable; selecting it is a no-op rather than
/// dropping D-pad focus.
class CountrySettingsTile extends ConsumerWidget {
  const CountrySettingsTile({super.key, this.forTv = false});

  final bool forTv;

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

    final shell = forTv ? ShellId.tv : ShellId.mobile;
    final country = iptvSettingsSections.firstWhere(
      (section) => section.id == IptvSettingsSectionId.country,
    );
    final title = country.labelFor(shell);
    final subtitle = filters.country != null
        ? countryLabel(filters.country)
        : channelsAsync.isLoading
        ? 'Loading countries…'
        : dimensions.countries.isEmpty
        ? 'Load channels first to choose a country'
        : 'Choose your default channel country';

    void openPicker() {
      if (!canPickCountry) return;
      unawaited(
        _showCountryPicker(
          context,
          ref,
          dimensions,
          filters.country,
          countryLabel,
        ),
      );
    }

    if (forTv) {
      final colorScheme = Theme.of(context).colorScheme;
      return ListView(
        children: [
          TvFocusable(
            autofocus: true,
            onSelect: openPicker,
            semanticLabel: title,
            semanticButton: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(country.iconFor(shell), color: colorScheme.onSurface),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListTile(
      leading: Icon(country.iconFor(shell)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      enabled: canPickCountry,
      onTap: canPickCountry ? openPicker : null,
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
    void onSelected(String country) {
      filters.setCountry(country);
      unawaited(countryPrompt.markCompleted());
    }

    void onClear() {
      filters.setCountry(null);
      unawaited(countryPrompt.markCompleted());
    }

    if (forTv) {
      return showTvLongListPicker(
        context: context,
        title: 'Country',
        options: dimensions.countries.toList(growable: false),
        selectedValue: selectedCountry,
        onSelected: onSelected,
        onClear: onClear,
        optionLabel: countryLabel,
      );
    }

    return showFilterOptionDialog(
      context: context,
      title: 'Country',
      options: dimensions.countries.toList(growable: false),
      selectedValue: selectedCountry,
      onSelected: onSelected,
      onClear: onClear,
      optionLabel: countryLabel,
    );
  }
}
