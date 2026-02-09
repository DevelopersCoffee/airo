import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/media_hub_providers.dart';
import '../../domain/models/media_category.dart';
import 'category_chip.dart';

/// A horizontal scrollable bar of category chips for content filtering.
///
/// Features:
/// - Shows categories contextual to the current media mode (Music/TV)
/// - "All" chip to clear category filter
/// - Smooth horizontal scrolling
/// - Active chip highlighting with 200ms animation
/// - Selection filters content instantly via selectedCategoryProvider
class CategoryChipsBar extends ConsumerWidget {
  const CategoryChipsBar({
    super.key,
    this.height = 48.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.chipSpacing = 8.0,
    this.onCategorySelected,
  });

  /// Height of the chips bar
  final double height;

  /// Padding around the scrollable area
  final EdgeInsets padding;

  /// Spacing between chips
  final double chipSpacing;

  /// Optional callback when a category is selected
  final void Function(MediaCategory?)? onCategorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(availableCategoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: categories.length + 1, // +1 for "All" chip
        separatorBuilder: (context, index) => SizedBox(width: chipSpacing),
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" chip at the beginning
            return AllCategoryChip(
              isSelected: selectedCategory == null,
              onTap: () => _selectCategory(ref, null),
            );
          }

          final category = categories[index - 1];
          return CategoryChip(
            category: category,
            isSelected: selectedCategory?.id == category.id,
            onTap: () => _selectCategory(ref, category),
          );
        },
      ),
    );
  }

  void _selectCategory(WidgetRef ref, MediaCategory? category) {
    ref.read(selectedCategoryProvider.notifier).state = category;
    onCategorySelected?.call(category);
  }
}

/// A compact version of the category chips bar for smaller spaces
class CompactCategoryChipsBar extends ConsumerWidget {
  const CompactCategoryChipsBar({super.key, this.onCategorySelected});

  /// Optional callback when a category is selected
  final void Function(MediaCategory?)? onCategorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(availableCategoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // "All" chip
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _CompactChip(
              label: 'All',
              isSelected: selectedCategory == null,
              onTap: () {
                ref.read(selectedCategoryProvider.notifier).state = null;
                onCategorySelected?.call(null);
              },
            ),
          ),
          // Category chips
          ...categories.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _CompactChip(
                label: category.label,
                icon: category.icon,
                isSelected: selectedCategory?.id == category.id,
                onTap: () {
                  ref.read(selectedCategoryProvider.notifier).state = category;
                  onCategorySelected?.call(category);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CompactChip extends StatelessWidget {
  const _CompactChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: CategoryChip.animationDuration,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
