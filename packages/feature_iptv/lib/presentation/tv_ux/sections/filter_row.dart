import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/channel_filters_provider.dart';
import '../../../application/providers/iptv_org_api_providers.dart';
import 'channel_library_grid.dart';
import 'filter_dialogs.dart';
import 'search_overlay.dart';

class FilterRow extends ConsumerWidget {
  const FilterRow({
    super.key,
    required this.dimensions,
    this.autofocus = false,
    this.compact = false,
    this.sort,
    this.onSort,
    this.viewMode = ChannelViewMode.list,
    this.onViewModeChanged,
    this.onSearch,
  });

  final ChannelFilterDimensions dimensions;

  /// Seeds D-pad focus on the first (Search) chip when this is the topmost
  /// visible ten-foot chrome row.
  final bool autofocus;

  /// Lighter inactive-chip weight for the phone-width touch/cursor layout,
  /// so the active filter reads as the only prominent one. False keeps the
  /// original, higher-contrast chip background this row has always had on
  /// the ten-foot D-pad layout — legibility at TV viewing distance matters
  /// more there than the phone-only "too many equal-weight pills" feedback
  /// this flag was added for.
  final bool compact;

  /// Compact phone chrome: sort lives on this row with search/filters.
  final ChannelSort? sort;
  final ValueChanged<ChannelSortColumn>? onSort;
  final ChannelViewMode viewMode;
  final ValueChanged<ChannelViewMode>? onViewModeChanged;

  /// When set, the Search chip opens this instead of [SearchOverlay]
  /// (phone hosts keep the existing in-player search sheet).
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(channelFiltersProvider);
    final notifier = ref.read(channelFiltersProvider.notifier);
    final recent = ref.watch(recentFilterValuesProvider);
    final recentNotifier = ref.read(recentFilterValuesProvider.notifier);
    final languages = ref.watch(iptvOrgLanguageByCodeProvider);
    final languageNames = {
      for (final entry in languages.entries) entry.key: entry.value.name,
    };
    String languageLabel(String? value) =>
        languageDisplayLabel(value, taxonomyNames: languageNames);
    final chips = <Widget>[
      if (sort != null)
        ChannelLibrarySortChip(sort: sort!, onSort: onSort, height: 48),
      _FilterChip(
        key: const ValueKey('filter-chip-search'),
        label: filters.search.isEmpty ? 'Search' : filters.search,
        active: filters.search.isNotEmpty,
        icon: Icons.search,
        onSelected: () {
          final search = onSearch;
          if (search != null) {
            search();
            return;
          }
          _showSearchOverlay(context, dimensions, notifier, filters.search);
        },
        onClear: filters.search.isEmpty ? null : () => notifier.setSearch(''),
        autofocus: autofocus,
        compact: compact,
      ),
      if (dimensions.categories.isNotEmpty)
        _FilterChip(
          key: const ValueKey('filter-chip-category'),
          label: filters.category ?? 'Category',
          active: filters.category != null,
          icon: Icons.category_outlined,
          compact: compact,
          onSelected: () => showTvLongListPicker(
            context: context,
            title: 'Category',
            options: dimensions.categories.toList(growable: false),
            selectedValue: filters.category,
            recentValues: recent.categories,
            onSelected: (value) {
              notifier.setCategory(value);
              recentNotifier.record(ChannelFilterDimension.category, value);
            },
            onClear: () => notifier.setCategory(null),
          ),
        ),
      if (dimensions.languages.isNotEmpty)
        _FilterChip(
          key: const ValueKey('filter-chip-language'),
          label: languageLabel(filters.language),
          active: filters.language != null,
          icon: Icons.translate,
          compact: compact,
          onSelected: () => showTvLongListPicker(
            context: context,
            title: 'Language',
            options: dimensions.languages.toList(growable: false),
            selectedValue: filters.language,
            recentValues: recent.languages,
            onSelected: (value) {
              notifier.setLanguage(value);
              recentNotifier.record(ChannelFilterDimension.language, value);
            },
            onClear: () => notifier.setLanguage(null),
            optionLabel: languageLabel,
          ),
        ),
      if (onViewModeChanged != null)
        ChannelViewModeToggle(mode: viewMode, onChanged: onViewModeChanged!),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760 &&
            sort == null &&
            onViewModeChanged == null &&
            chips.length >= 3) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (var i = 0; i < chips.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _expandChip(chips[i])),
                ],
              ],
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final chip in chips) ...[chip, const SizedBox(width: 8)],
            ],
          ),
        );
      },
    );
  }

  Widget _expandChip(Widget chip) {
    if (chip is _FilterChip) {
      return _FilterChip(
        key: chip.key,
        label: chip.label,
        active: chip.active,
        icon: chip.icon,
        onSelected: chip.onSelected,
        onClear: chip.onClear,
        expanded: true,
        compact: chip.compact,
      );
    }
    return chip;
  }
}

Future<void> _showSearchOverlay(
  BuildContext context,
  ChannelFilterDimensions dimensions,
  ChannelFiltersNotifier notifier,
  String initialValue,
) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (dialogContext) => SearchOverlay(
      dimensions: dimensions,
      notifier: notifier,
      initialQuery: initialValue,
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.icon,
    required this.onSelected,
    this.onClear,
    this.expanded = false,
    this.autofocus = false,
    this.compact = false,
  });

  final String label;
  final bool active;
  final IconData icon;
  final VoidCallback onSelected;
  final VoidCallback? onClear;
  final bool expanded;
  final bool autofocus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = active
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest.withValues(
            alpha: compact ? 0.46 : 0.72,
          );
    final foreground = active
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    final filterButton = TvFocusable(
      semanticLabel: label,
      onSelect: onSelected,
      autofocus: autofocus,
      borderRadius: 12,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onSelected,
          child: Container(
            height: 48,
            width: expanded ? double.infinity : null,
            constraints: BoxConstraints(
              minWidth: 112,
              maxWidth: expanded ? double.infinity : 220,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 8),
                if (expanded)
                  Expanded(
                    child: _FilterChipLabel(label: label, active: active),
                  )
                else
                  Flexible(
                    child: _FilterChipLabel(label: label, active: active),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final clear = onClear;
    if (clear == null) return filterButton;

    final clearButton = TvFocusable(
      key: const ValueKey('filter-chip-search-clear'),
      semanticLabel: 'Clear search',
      onSelect: clear,
      borderRadius: 12,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: IconButton(
          tooltip: 'Clear search',
          onPressed: clear,
          icon: Icon(Icons.close, color: scheme.onPrimaryContainer),
        ),
      ),
    );

    return Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (expanded) Expanded(child: filterButton) else filterButton,
        const SizedBox(width: 4),
        clearButton,
      ],
    );
  }
}

class _FilterChipLabel extends StatelessWidget {
  const _FilterChipLabel({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = active
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return Text(
      label,
      key: ValueKey('filter-chip-label-$label'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        color: foreground,
        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
      ),
    );
  }
}
