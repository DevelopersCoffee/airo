import 'dart:async';

import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/filter_dialogs.dart';
import '../../../../core/providers/app_theme_provider.dart';
import 'audio_settings_screen.dart';

/// Resolves a section descriptor from the shared
/// [iptvSettingsSections] manifest by [id] — the same manifest
/// `TvSettingsScreen` renders from. Throws if [id] isn't declared, which
/// would mean the manifest and this screen have drifted.
IptvSettingsSectionDescriptor _section(IptvSettingsSectionId id) =>
    iptvSettingsSections.firstWhere((section) => section.id == id);

/// Mobile settings hub (CV item 3): the mobile counterpart to
/// [TvSettingsScreen] — a single scrollable list rather than a rail/detail
/// split, since phone screens don't have room for a persistent side rail.
/// Aggregates appearance and links to the
/// dedicated Audio/Playback/Source screens that previously lived inline in
/// `ProfileScreen`. Section labels below come from the shared
/// `iptvSettingsSections` manifest (SSOT with the TV settings screen); only
/// this list's layout (single scrollable column vs. TV's rail/detail split)
/// stays mobile-specific.
class SettingsHubScreen extends ConsumerWidget {
  const SettingsHubScreen({super.key, this.onRootBack});

  /// Optional fallback used when this screen is the root route of a compact
  /// host app (for example Airo TV on phones) and Android back should return
  /// to the app's primary surface instead of doing nothing.
  final VoidCallback? onRootBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPop = Navigator.of(context).canPop();
    final shouldUseRootBack = onRootBack != null && !canPop;

    return PopScope<void>(
      canPop: !shouldUseRootBack,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && shouldUseRootBack) {
          onRootBack?.call();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: shouldUseRootBack
                ? onRootBack
                : () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Settings'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _section(IptvSettingsSectionId.theme).labelFor(ShellId.mobile),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            RadioGroup<AppThemeId>(
              groupValue: ref.watch(appThemeProvider),
              onChanged: (themeId) {
                if (themeId != null) {
                  ref.read(appThemeProvider.notifier).setTheme(themeId);
                }
              },
              child: Column(
                children: [
                  for (final theme in AppTheme.themes)
                    RadioListTile<AppThemeId>(
                      value: theme.id,
                      title: Text(theme.name),
                      subtitle: Text(theme.description),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            ListTile(
              leading: Icon(
                _section(IptvSettingsSectionId.audio).iconFor(ShellId.mobile),
              ),
              title: Text(
                _section(IptvSettingsSectionId.audio).labelFor(ShellId.mobile),
              ),
              subtitle: const Text('Configure context-aware audio behavior'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AudioSettingsScreen(),
                  ),
                );
              },
            ),

            ListTile(
              leading: Icon(
                _section(
                  IptvSettingsSectionId.playback,
                ).iconFor(ShellId.mobile),
              ),
              title: Text(
                _section(
                  IptvSettingsSectionId.playback,
                ).labelFor(ShellId.mobile),
              ),
              subtitle: const Text('Configure video aspect ratio'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PlaybackSettingsScreen(),
                  ),
                );
              },
            ),

            const _CountrySettingsTile(),

            ListTile(
              leading: Icon(
                _section(
                  IptvSettingsSectionId.playlistSource,
                ).iconFor(ShellId.mobile),
              ),
              title: Text(
                _section(
                  IptvSettingsSectionId.playlistSource,
                ).labelFor(ShellId.mobile),
              ),
              subtitle: const Text('Add or remove your M3U playlist URL'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => showPlaylistSourceSheet(context, ref),
            ),

            ListTile(
              leading: Icon(
                _section(
                  IptvSettingsSectionId.epgGuideSource,
                ).iconFor(ShellId.mobile),
              ),
              title: Text(
                _section(
                  IptvSettingsSectionId.epgGuideSource,
                ).labelFor(ShellId.mobile),
              ),
              subtitle: const Text('Add or refresh your XMLTV guide URL'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => showXmltvSourceSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountrySettingsTile extends ConsumerWidget {
  const _CountrySettingsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(channelFiltersProvider);
    final channelsAsync = ref.watch(iptvChannelsProvider);
    final channels = channelsAsync.value ?? const <IPTVChannel>[];
    final dimensions = channelFilterDimensions(
      channels: channels,
      metadataByChannelId: const {},
    );
    final canPickCountry =
        dimensions.countries.isNotEmpty || filters.country != null;

    final country = _section(IptvSettingsSectionId.country);
    return ListTile(
      leading: Icon(country.iconFor(ShellId.mobile)),
      title: Text(country.labelFor(ShellId.mobile)),
      subtitle: Text(
        filters.country != null
            ? countryDisplayLabel(filters.country)
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
          : () => _showCountryPicker(context, ref, dimensions, filters.country),
    );
  }

  Future<void> _showCountryPicker(
    BuildContext context,
    WidgetRef ref,
    ChannelFilterDimensions dimensions,
    String? selectedCountry,
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
      optionLabel: countryDisplayLabel,
    );
  }
}
