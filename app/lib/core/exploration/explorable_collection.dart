import 'dart:math';

import 'package:flutter/material.dart';

enum ExplorableCollectionViewMode { list, spatial }

enum ExplorableCollectionSortMode { original, title, category, group }

class ExplorableCollectionItem<T> {
  const ExplorableCollectionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.group,
    this.details,
    this.tags = const [],
    this.metrics = const {},
    this.icon,
    this.color,
    this.semanticLabel,
    this.payload,
  });

  final String id;
  final String title;
  final String subtitle;
  final String category;
  final String group;
  final String? details;
  final List<String> tags;
  final Map<String, String> metrics;
  final IconData? icon;
  final Color? color;
  final String? semanticLabel;
  final T? payload;
}

class ExplorableCollection<T> extends StatefulWidget {
  const ExplorableCollection({
    super.key,
    required this.title,
    required this.items,
    this.subtitle,
    this.listLabel = 'List View',
    this.spatialLabel = 'Place View',
    this.searchHint = 'Search collection',
    this.allCategoriesLabel = 'All',
    this.randomLabel = 'Random',
    this.listHelpText = 'Search, filter, and compare items.',
    this.spatialHelpText = 'Browse by adjacency and open nearby items.',
    this.loadingLabel = 'Arranging the collection...',
    this.emptyTitle = 'No matching items',
    this.emptyMessage = 'Change the search or filters to widen the view.',
    this.isLoading = false,
    this.initialViewMode = ExplorableCollectionViewMode.list,
    this.randomSeed,
    this.onItemSelected,
  });

  final String title;
  final String? subtitle;
  final List<ExplorableCollectionItem<T>> items;
  final String listLabel;
  final String spatialLabel;
  final String searchHint;
  final String allCategoriesLabel;
  final String randomLabel;
  final String listHelpText;
  final String spatialHelpText;
  final String loadingLabel;
  final String emptyTitle;
  final String emptyMessage;
  final bool isLoading;
  final ExplorableCollectionViewMode initialViewMode;
  final int? randomSeed;
  final ValueChanged<ExplorableCollectionItem<T>>? onItemSelected;

  @override
  State<ExplorableCollection<T>> createState() =>
      _ExplorableCollectionState<T>();
}

class _ExplorableCollectionState<T> extends State<ExplorableCollection<T>> {
  late ExplorableCollectionViewMode _viewMode;
  late final Random _random;
  final TextEditingController _searchController = TextEditingController();
  String _category = '';
  ExplorableCollectionSortMode _sortMode =
      ExplorableCollectionSortMode.original;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;
    _category = widget.allCategoriesLabel;
    _random = Random(widget.randomSeed);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;
    if (!categories.contains(_category)) {
      _category = widget.allCategoriesLabel;
    }

    final filteredItems = _filteredItems;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _CollectionHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            count: filteredItems.length,
            total: widget.items.length,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _CollectionControls(
            searchController: _searchController,
            searchHint: widget.searchHint,
            categories: categories,
            selectedCategory: _category,
            sortMode: _sortMode,
            viewMode: _viewMode,
            listLabel: widget.listLabel,
            spatialLabel: widget.spatialLabel,
            randomLabel: widget.randomLabel,
            randomEnabled: filteredItems.isNotEmpty,
            onQueryChanged: (_) => setState(() {}),
            onCategoryChanged: (value) {
              setState(() => _category = value ?? widget.allCategoriesLabel);
            },
            onSortChanged: (value) {
              setState(() => _sortMode = value);
            },
            onViewChanged: (value) {
              setState(() => _viewMode = value);
            },
            onRandom: () => _selectRandom(filteredItems),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            _viewMode == ExplorableCollectionViewMode.list
                ? widget.listHelpText
                : widget.spatialHelpText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: widget.isLoading
                ? _CollectionLoading(label: widget.loadingLabel)
                : filteredItems.isEmpty
                ? _CollectionEmpty(
                    title: widget.emptyTitle,
                    message: widget.emptyMessage,
                  )
                : _viewMode == ExplorableCollectionViewMode.list
                ? _CollectionList<T>(
                    key: const ValueKey('explorable_collection_list'),
                    items: filteredItems,
                    onItemSelected: _selectItem,
                  )
                : _SpatialCollection<T>(
                    key: const ValueKey('explorable_collection_spatial'),
                    items: filteredItems,
                    onItemSelected: _selectItem,
                  ),
          ),
        ),
      ],
    );
  }

  List<String> get _categories {
    final values = widget.items.map((item) => item.category).toSet().toList()
      ..sort();
    return [widget.allCategoriesLabel, ...values];
  }

  List<ExplorableCollectionItem<T>> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = <ExplorableCollectionItem<T>>[];

    for (final item in widget.items) {
      if (_category != widget.allCategoriesLabel &&
          item.category != _category) {
        continue;
      }
      if (query.isNotEmpty && !_matchesQuery(item, query)) {
        continue;
      }
      filtered.add(item);
    }

    switch (_sortMode) {
      case ExplorableCollectionSortMode.original:
        return filtered;
      case ExplorableCollectionSortMode.title:
        return [...filtered]..sort((a, b) => a.title.compareTo(b.title));
      case ExplorableCollectionSortMode.category:
        return [...filtered]..sort(
          (a, b) => _compareByMany(a, b, [
            (item) => item.category,
            (item) => item.title,
          ]),
        );
      case ExplorableCollectionSortMode.group:
        return [...filtered]..sort(
          (a, b) => _compareByMany(a, b, [
            (item) => item.group,
            (item) => item.title,
          ]),
        );
    }
  }

  bool _matchesQuery(ExplorableCollectionItem<T> item, String query) {
    final searchable = [
      item.title,
      item.subtitle,
      item.category,
      item.group,
      item.details ?? '',
      ...item.tags,
      ...item.metrics.values,
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }

  int _compareByMany(
    ExplorableCollectionItem<T> a,
    ExplorableCollectionItem<T> b,
    List<String Function(ExplorableCollectionItem<T>)> selectors,
  ) {
    for (final selector in selectors) {
      final result = selector(a).compareTo(selector(b));
      if (result != 0) return result;
    }
    return 0;
  }

  void _selectRandom(List<ExplorableCollectionItem<T>> items) {
    if (items.isEmpty) return;
    _selectItem(items[_random.nextInt(items.length)]);
  }

  void _selectItem(ExplorableCollectionItem<T> item) {
    widget.onItemSelected?.call(item);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ItemDetailSheet(item: item),
    );
  }
}

class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.total,
  });

  final String title;
  final String? subtitle;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          label: '$count of $total items visible',
          child: Chip(
            label: Text('$count/$total'),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

class _CollectionControls extends StatelessWidget {
  const _CollectionControls({
    required this.searchController,
    required this.searchHint,
    required this.categories,
    required this.selectedCategory,
    required this.sortMode,
    required this.viewMode,
    required this.listLabel,
    required this.spatialLabel,
    required this.randomLabel,
    required this.randomEnabled,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onSortChanged,
    required this.onViewChanged,
    required this.onRandom,
  });

  final TextEditingController searchController;
  final String searchHint;
  final List<String> categories;
  final String selectedCategory;
  final ExplorableCollectionSortMode sortMode;
  final ExplorableCollectionViewMode viewMode;
  final String listLabel;
  final String spatialLabel;
  final String randomLabel;
  final bool randomEnabled;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<ExplorableCollectionSortMode> onSortChanged;
  final ValueChanged<ExplorableCollectionViewMode> onViewChanged;
  final VoidCallback onRandom;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;

    final searchField = TextField(
      key: const ValueKey('explorable_collection_search'),
      controller: searchController,
      onChanged: onQueryChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: searchHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close),
                onPressed: () {
                  searchController.clear();
                  onQueryChanged('');
                },
              ),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );

    final filters = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: compact ? double.infinity : 180,
          child: DropdownButtonFormField<String>(
            key: const ValueKey('explorable_collection_category'),
            initialValue: selectedCategory,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Filter',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final category in categories)
                DropdownMenuItem(value: category, child: Text(category)),
            ],
            onChanged: onCategoryChanged,
          ),
        ),
        PopupMenuButton<ExplorableCollectionSortMode>(
          key: const ValueKey('explorable_collection_sort'),
          tooltip: 'Sort',
          icon: const Icon(Icons.sort),
          initialValue: sortMode,
          onSelected: onSortChanged,
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: ExplorableCollectionSortMode.original,
              child: Text('Original order'),
            ),
            PopupMenuItem(
              value: ExplorableCollectionSortMode.title,
              child: Text('Title'),
            ),
            PopupMenuItem(
              value: ExplorableCollectionSortMode.category,
              child: Text('Category'),
            ),
            PopupMenuItem(
              value: ExplorableCollectionSortMode.group,
              child: Text('Group'),
            ),
          ],
        ),
        FilledButton.icon(
          key: const ValueKey('explorable_collection_random'),
          onPressed: randomEnabled ? onRandom : null,
          icon: const Icon(Icons.shuffle),
          label: Text(randomLabel),
        ),
        SegmentedButton<ExplorableCollectionViewMode>(
          key: const ValueKey('explorable_collection_view_switcher'),
          segments: [
            ButtonSegment(
              value: ExplorableCollectionViewMode.list,
              label: Text(listLabel),
              icon: const Icon(Icons.view_list_outlined),
            ),
            ButtonSegment(
              value: ExplorableCollectionViewMode.spatial,
              label: Text(spatialLabel),
              icon: const Icon(Icons.map_outlined),
            ),
          ],
          selected: {viewMode},
          onSelectionChanged: (selection) => onViewChanged(selection.first),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [searchField, const SizedBox(height: 8), filters],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: searchField),
        const SizedBox(width: 8),
        Flexible(flex: 2, child: filters),
      ],
    );
  }
}

class _CollectionList<T> extends StatelessWidget {
  const _CollectionList({
    super.key,
    required this.items,
    required this.onItemSelected,
  });

  final List<ExplorableCollectionItem<T>> items;
  final ValueChanged<ExplorableCollectionItem<T>> onItemSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final color = item.color ?? Theme.of(context).colorScheme.primary;
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: ListTile(
            key: ValueKey('explorable_list_item_${item.id}'),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(
                item.icon ?? Icons.inventory_2_outlined,
                color: color,
              ),
            ),
            title: Text(item.title),
            subtitle: Text(
              '${item.subtitle}\n${item.group} / ${item.category}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onItemSelected(item),
          ),
        );
      },
    );
  }
}

class _SpatialCollection<T> extends StatelessWidget {
  const _SpatialCollection({
    super.key,
    required this.items,
    required this.onItemSelected,
  });

  final List<ExplorableCollectionItem<T>> items;
  final ValueChanged<ExplorableCollectionItem<T>> onItemSelected;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ExplorableCollectionItem<T>>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.group, () => []).add(item);
    }

    return ListView(
      key: const ValueKey('explorable_spatial_lanes'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(
              entry.key,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          _SpatialLane(items: entry.value, onItemSelected: onItemSelected),
        ],
      ],
    );
  }
}

class _SpatialLane<T> extends StatelessWidget {
  const _SpatialLane({required this.items, required this.onItemSelected});

  final List<ExplorableCollectionItem<T>> items;
  final ValueChanged<ExplorableCollectionItem<T>> onItemSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: SizedBox(
        height: 132,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(10),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final color = item.color ?? theme.colorScheme.primary;
            return Semantics(
              button: true,
              label: item.semanticLabel ?? '${item.title}, ${item.subtitle}',
              child: InkWell(
                key: ValueKey('explorable_spatial_item_${item.id}'),
                onTap: () => onItemSelected(item),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 88,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border(left: BorderSide(color: color, width: 5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.icon ?? Icons.place_outlined, color: color),
                      const Spacer(),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ItemDetailSheet<T> extends StatelessWidget {
  const _ItemDetailSheet({required this.item});

  final ExplorableCollectionItem<T> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.color ?? theme.colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(
                    item.icon ?? Icons.inventory_2_outlined,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item.details != null) ...[
              const SizedBox(height: 16),
              Text(item.details!),
            ],
            if (item.metrics.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final metric in item.metrics.entries)
                    Chip(label: Text('${metric.key}: ${metric.value}')),
                ],
              ),
            ],
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in item.tags)
                    Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CollectionLoading extends StatelessWidget {
  const _CollectionLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: label,
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _CollectionEmpty extends StatelessWidget {
  const _CollectionEmpty({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
