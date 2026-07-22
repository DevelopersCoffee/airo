import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/channel_filters_provider.dart';
import 'filter_dialogs.dart';

class FilterRow extends ConsumerWidget {
  const FilterRow({super.key, required this.dimensions});

  final ChannelFilterDimensions dimensions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(channelFiltersProvider);
    final notifier = ref.read(channelFiltersProvider.notifier);
    final chips = <Widget>[
      _FilterChip(
        key: const ValueKey('filter-chip-search'),
        label: filters.search.isEmpty ? 'Search' : filters.search,
        active: filters.search.isNotEmpty,
        icon: Icons.search,
        onSelected: () => _showSearchDialog(context, notifier, filters.search),
      ),
      if (dimensions.categories.isNotEmpty)
        _FilterChip(
          key: const ValueKey('filter-chip-category'),
          label: filters.category ?? 'Category',
          active: filters.category != null,
          icon: Icons.category_outlined,
          onSelected: () => showFilterOptionDialog(
            context: context,
            title: 'Category',
            options: dimensions.categories.toList(growable: false),
            selectedValue: filters.category,
            onSelected: notifier.setCategory,
            onClear: () => notifier.setCategory(null),
          ),
        ),
      if (dimensions.countries.isNotEmpty)
        _FilterChip(
          key: const ValueKey('filter-chip-country'),
          label: countryDisplayLabel(filters.country),
          active: filters.country != null,
          icon: Icons.flag,
          onSelected: () => showFilterOptionDialog(
            context: context,
            title: 'Country',
            options: dimensions.countries.toList(growable: false),
            selectedValue: filters.country,
            onSelected: notifier.setCountry,
            onClear: () => notifier.setCountry(null),
            optionLabel: countryDisplayLabel,
          ),
        ),
      if (dimensions.languages.isNotEmpty)
        _FilterChip(
          key: const ValueKey('filter-chip-language'),
          label: languageDisplayLabel(filters.language),
          active: filters.language != null,
          icon: Icons.translate,
          onSelected: () => showFilterOptionDialog(
            context: context,
            title: 'Language',
            options: dimensions.languages.toList(growable: false),
            selectedValue: filters.language,
            onSelected: notifier.setLanguage,
            onClear: () => notifier.setLanguage(null),
            optionLabel: languageDisplayLabel,
          ),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760 && chips.length >= 4) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 12, child: _expandChip(chips[0])),
                const SizedBox(width: 8),
                Expanded(flex: 13, child: _expandChip(chips[1])),
                const SizedBox(width: 8),
                Expanded(flex: 14, child: _expandChip(chips[2])),
                const SizedBox(width: 8),
                Expanded(flex: 13, child: _expandChip(chips[3])),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        expanded: true,
      );
    }
    return chip;
  }
}

Future<void> _showSearchDialog(
  BuildContext context,
  ChannelFiltersNotifier notifier,
  String initialValue,
) async {
  var searchText = initialValue;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Search channels'),
        content: TextFormField(
          key: const ValueKey('filter-search-field'),
          initialValue: initialValue,
          autofocus: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search by channel name',
          ),
          textInputAction: TextInputAction.search,
          onChanged: (value) => searchText = value,
          onFieldSubmitted: (value) {
            notifier.setSearch(value);
            Navigator.of(dialogContext).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              notifier.setSearch('');
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () {
              notifier.setSearch(searchText);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      );
    },
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.icon,
    required this.onSelected,
    this.expanded = false,
  });

  final String label;
  final bool active;
  final IconData icon;
  final VoidCallback onSelected;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = active
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest.withValues(alpha: 0.72);
    final foreground = active
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return TvFocusable(
      semanticLabel: label,
      onSelect: onSelected,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onSelected,
          child: Container(
            height: 40,
            width: expanded ? double.infinity : null,
            constraints: const BoxConstraints(minWidth: 112),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: 8),
                if (expanded)
                  Expanded(
                    child: _FilterChipLabel(label: label, active: active),
                  )
                else
                  _FilterChipLabel(label: label, active: active),
              ],
            ),
          ),
        ),
      ),
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
