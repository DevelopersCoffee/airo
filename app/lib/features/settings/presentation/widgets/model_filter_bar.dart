import 'package:flutter/material.dart';
import 'package:core_ai/core_ai.dart';

/// Filter options for the model browser.
class ModelFilters {
  const ModelFilters({
    this.family,
    this.credibility,
    this.downloaded,
    this.searchQuery,
    this.showCompatibleOnly = false,
  });

  final ModelFamily? family;
  final ModelCredibility? credibility;
  final bool? downloaded;
  final String? searchQuery;
  final bool showCompatibleOnly;

  ModelFilters copyWith({
    ModelFamily? family,
    ModelCredibility? credibility,
    bool? downloaded,
    String? searchQuery,
    bool? showCompatibleOnly,
    bool clearFamily = false,
    bool clearCredibility = false,
    bool clearDownloaded = false,
    bool clearSearch = false,
  }) {
    return ModelFilters(
      family: clearFamily ? null : (family ?? this.family),
      credibility: clearCredibility ? null : (credibility ?? this.credibility),
      downloaded: clearDownloaded ? null : (downloaded ?? this.downloaded),
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      showCompatibleOnly: showCompatibleOnly ?? this.showCompatibleOnly,
    );
  }

  bool get hasActiveFilters =>
      family != null ||
      credibility != null ||
      downloaded != null ||
      (searchQuery?.isNotEmpty ?? false);
}

/// A filter bar widget for the model browser.
///
/// Includes search, family filter, credibility filter, and compatibility toggle.
class ModelFilterBar extends StatelessWidget {
  const ModelFilterBar({
    super.key,
    required this.filters,
    required this.onFiltersChanged,
  });

  final ModelFilters filters;
  final ValueChanged<ModelFilters> onFiltersChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search models...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: filters.searchQuery?.isNotEmpty == true
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          onFiltersChanged(filters.copyWith(clearSearch: true)),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) =>
                onFiltersChanged(filters.copyWith(searchQuery: value)),
          ),
        ),

        // Filter chips
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Compatibility toggle
              FilterChip(
                label: const Text('Compatible only'),
                selected: filters.showCompatibleOnly,
                onSelected: (selected) => onFiltersChanged(
                  filters.copyWith(showCompatibleOnly: selected),
                ),
              ),
              const SizedBox(width: 8),

              // Downloaded filter
              _DropdownFilterChip<bool?>(
                label: 'Status',
                value: filters.downloaded,
                options: const [
                  (null, 'All'),
                  (true, 'Downloaded'),
                  (false, 'Available'),
                ],
                onChanged: (value) => onFiltersChanged(
                  value == null
                      ? filters.copyWith(clearDownloaded: true)
                      : filters.copyWith(downloaded: value),
                ),
              ),
              const SizedBox(width: 8),

              // Family filter
              _DropdownFilterChip<ModelFamily?>(
                label: 'Family',
                value: filters.family,
                options: [
                  (null, 'All'),
                  ...ModelFamily.values.map((f) => (f, f.displayName)),
                ],
                onChanged: (value) => onFiltersChanged(
                  value == null
                      ? filters.copyWith(clearFamily: true)
                      : filters.copyWith(family: value),
                ),
              ),
              const SizedBox(width: 8),

              // Credibility filter
              _DropdownFilterChip<ModelCredibility?>(
                label: 'Source',
                value: filters.credibility,
                options: [
                  (null, 'All'),
                  ...ModelCredibility.values.map((c) => (c, c.displayName)),
                ],
                onChanged: (value) => onFiltersChanged(
                  value == null
                      ? filters.copyWith(clearCredibility: true)
                      : filters.copyWith(credibility: value),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A filter chip that shows a dropdown menu when tapped.
class _DropdownFilterChip<T> extends StatelessWidget {
  const _DropdownFilterChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedLabel = options
        .firstWhere((o) => o.$1 == value, orElse: () => options.first)
        .$2;

    return PopupMenuButton<T>(
      onSelected: onChanged,
      offset: const Offset(0, 40),
      itemBuilder: (context) => options
          .map(
            (option) => PopupMenuItem<T>(
              value: option.$1,
              child: Row(
                children: [
                  if (option.$1 == value)
                    Icon(
                      Icons.check,
                      size: 18,
                      color: theme.colorScheme.primary,
                    )
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(option.$2),
                ],
              ),
            ),
          )
          .toList(),
      child: Chip(
        label: Text(
          value == null ? label : '$label: $selectedLabel',
          style: TextStyle(
            color: value != null ? theme.colorScheme.primary : null,
          ),
        ),
        deleteIcon: value != null
            ? Icon(Icons.arrow_drop_down, size: 18)
            : Icon(Icons.arrow_drop_down, size: 18),
        onDeleted: () {}, // Required for the icon to show, popup handles action
        backgroundColor: value != null
            ? theme.colorScheme.primaryContainer
            : null,
      ),
    );
  }
}
