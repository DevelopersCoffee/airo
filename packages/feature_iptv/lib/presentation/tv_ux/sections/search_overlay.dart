import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/channel_filters_provider.dart';
import '../../../application/providers/local_iptv_search_providers.dart';
import '../../../application/providers/iptv_org_api_providers.dart';
import '../../widgets/local_search_results_panel.dart';
import 'filter_dialogs.dart';

/// AiroTV D-pad design's "SEARCH — browse first, typing last" screen:
/// category/country/language tiles up top (a D-pad remote makes typing
/// expensive; browsing is nearly free), the text field and live results
/// below for when browsing isn't enough.
///
/// Opened from [FilterRow]'s search chip in place of the previous bare
/// [AlertDialog] + [TextFormField].
class SearchOverlay extends ConsumerStatefulWidget {
  const SearchOverlay({
    super.key,
    required this.dimensions,
    required this.notifier,
    required this.initialQuery,
  });

  final ChannelFilterDimensions dimensions;
  final ChannelFiltersNotifier notifier;
  final String initialQuery;

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localIptvSearchQueryProvider.notifier).state =
          widget.initialQuery;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    final query = ref.read(localIptvSearchQueryProvider);
    widget.notifier.setSearch(query);
    Navigator.of(context).pop();
  }

  Future<void> _browseBy({
    required String title,
    required ChannelFilterDimension dimension,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
    required VoidCallback onClear,
    String Function(String)? optionLabel,
  }) async {
    Navigator.of(context).pop();
    final recentNotifier = ref.read(recentFilterValuesProvider.notifier);
    await showTvLongListPicker(
      // ignore: use_build_context_synchronously
      context: context,
      title: title,
      options: options,
      selectedValue: selectedValue,
      recentValues: ref.read(
        recentFilterValuesProvider.select((r) => r.forDimension(dimension)),
      ),
      onSelected: (value) {
        onSelected(value);
        recentNotifier.record(dimension, value);
      },
      onClear: onClear,
      optionLabel: optionLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = ref.watch(channelFiltersProvider);
    final dimensions = widget.dimensions;
    final countries = ref.watch(iptvOrgCountryByCodeProvider);
    final languages = ref.watch(iptvOrgLanguageByCodeProvider);
    String countryLabel(String? value) => countryDisplayLabel(
      value,
      taxonomyNames: {
        for (final entry in countries.entries) entry.key: entry.value.name,
      },
      taxonomyFlags: {
        for (final entry in countries.entries) entry.key: entry.value.flag,
      },
    );
    String languageLabel(String? value) => languageDisplayLabel(
      value,
      taxonomyNames: {
        for (final entry in languages.entries) entry.key: entry.value.name,
      },
    );

    return Dialog.fullscreen(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Find a channel',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  TvFocusable(
                    semanticLabel: 'Close search',
                    onSelect: _close,
                    borderRadius: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close search',
                      onPressed: _close,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Browsing is faster than typing on a remote. Type only if '
                'you must.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              if (dimensions.categories.isNotEmpty ||
                  dimensions.countries.isNotEmpty ||
                  dimensions.languages.isNotEmpty) ...[
                Text(
                  'Browse by',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 9),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (dimensions.categories.isNotEmpty)
                        _BrowseTile(
                          key: const ValueKey('search-browse-category'),
                          icon: Icons.category_outlined,
                          label: 'Category',
                          count: '${dimensions.categories.length}',
                          onSelect: () => _browseBy(
                            title: 'Category',
                            dimension: ChannelFilterDimension.category,
                            options: dimensions.categories.toList(
                              growable: false,
                            ),
                            selectedValue: filters.category,
                            onSelected: widget.notifier.setCategory,
                            onClear: () => widget.notifier.setCategory(null),
                          ),
                        ),
                      if (dimensions.countries.isNotEmpty)
                        _BrowseTile(
                          key: const ValueKey('search-browse-country'),
                          icon: Icons.flag_outlined,
                          label: 'Country',
                          count: '${dimensions.countries.length}',
                          onSelect: () => _browseBy(
                            title: 'Country',
                            dimension: ChannelFilterDimension.country,
                            options: dimensions.countries.toList(
                              growable: false,
                            ),
                            selectedValue: filters.country,
                            onSelected: widget.notifier.setCountry,
                            onClear: () => widget.notifier.setCountry(null),
                            optionLabel: countryLabel,
                          ),
                        ),
                      if (dimensions.languages.isNotEmpty)
                        _BrowseTile(
                          key: const ValueKey('search-browse-language'),
                          icon: Icons.translate_outlined,
                          label: 'Language',
                          count: '${dimensions.languages.length}',
                          onSelect: () => _browseBy(
                            title: 'Language',
                            dimension: ChannelFilterDimension.language,
                            options: dimensions.languages.toList(
                              growable: false,
                            ),
                            selectedValue: filters.language,
                            onSelected: widget.notifier.setLanguage,
                            onClear: () => widget.notifier.setLanguage(null),
                            optionLabel: languageLabel,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              TvFocusable(
                semanticLabel: 'Search field',
                borderRadius: 10,
                onSelect: () {},
                child: TextField(
                  key: const ValueKey('search-overlay-field'),
                  controller: _controller,
                  autofocus:
                      dimensions.categories.isEmpty &&
                      dimensions.countries.isEmpty &&
                      dimensions.languages.isEmpty,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Type a channel name',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (value) =>
                      ref.read(localIptvSearchQueryProvider.notifier).state =
                          value,
                  onSubmitted: (_) => _close(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LocalSearchResultsPanel(onChannelSelected: _close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowseTile extends StatelessWidget {
  const _BrowseTile({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.onSelect,
  });

  final IconData icon;
  final String label;
  final String count;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 11),
      child: TvFocusable(
        semanticLabel: 'Browse by $label',
        onSelect: onSelect,
        borderRadius: 11,
        child: Container(
          width: 148,
          height: 96,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
              Text(label, style: theme.textTheme.titleSmall),
              Text(
                count,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
