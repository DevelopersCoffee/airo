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
            onClear: notifier.clear,
          ),
        ),
      if (dimensions.countries.isNotEmpty)
        _FilterChip(
          key: const ValueKey('filter-chip-country'),
          label: filters.country ?? 'Country',
          active: filters.country != null,
          icon: Icons.public,
          onSelected: () => showFilterOptionDialog(
            context: context,
            title: 'Country',
            options: dimensions.countries.toList(growable: false),
            selectedValue: filters.country,
            onSelected: notifier.setCountry,
            onClear: notifier.clear,
          ),
        ),
      if (dimensions.languages.isNotEmpty)
        _FilterChip(
          key: const ValueKey('filter-chip-language'),
          label: filters.language ?? 'Language',
          active: filters.language != null,
          icon: Icons.translate,
          onSelected: () => showFilterOptionDialog(
            context: context,
            title: 'Language',
            options: dimensions.languages.toList(growable: false),
            selectedValue: filters.language,
            onSelected: notifier.setLanguage,
            onClear: notifier.clear,
          ),
        ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final chip in chips) ...[chip, const SizedBox(width: 8)],
        ],
      ),
    );
  }

  Future<void> _showSearchDialog(
    BuildContext context,
    ChannelFiltersNotifier notifier,
    String initialValue,
  ) async {
    final controller = TextEditingController(text: initialValue);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search channels'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) {
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
              notifier.setSearch(controller.text);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final bool active;
  final IconData icon;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      semanticLabel: label,
      onSelect: onSelected,
      child: ChoiceChip(
        selected: active,
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
