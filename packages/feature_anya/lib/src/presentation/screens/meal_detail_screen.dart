import 'package:core_ui/core_ui.dart';
import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/anya_providers.dart';

class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({required this.mealId, super.key});

  final String mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(anyaSessionProvider);
    final plan = session.weeklyPlan;
    final matches = plan?.meals.where((item) => item.id == mealId) ?? const [];
    final meal = matches.isEmpty ? null : matches.first;
    if (meal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meal')),
        body: const EmptyStateWidget(
          title: 'Meal not found',
          message: 'This meal is not in the current week.',
        ),
      );
    }
    final nutrition = meal.nutrition;
    return Scaffold(
      appBar: AppBar(title: Text(meal.meal.name)),
      body: ListView(
        padding: AiroSpacing.paddingMd,
        children: [
          Text(
            meal.meal.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AiroSpacing.sm),
          Text(
            '${nutrition.calories} kcal · P ${nutrition.proteinG.toStringAsFixed(0)}g · '
            'C ${nutrition.carbsG.toStringAsFixed(0)}g · F ${nutrition.fatG.toStringAsFixed(0)}g',
          ),
          Text(
            '${meal.meal.cookTimeMinutes} min · ${meal.servings} servings · '
            '${meal.estimatedCost.toStringAsFixed(2)} est.',
          ),
          const SizedBox(height: AiroSpacing.lg),
          Text('Ingredients', style: Theme.of(context).textTheme.titleMedium),
          for (final ingredient in meal.meal.ingredients)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(ingredient.name),
              trailing: Text(
                '${(ingredient.quantity * meal.servingFactor).toStringAsFixed(0)} ${ingredient.unit}',
              ),
            ),
          const SizedBox(height: AiroSpacing.md),
          Text('Method', style: Theme.of(context).textTheme.titleMedium),
          for (final step in meal.meal.instructions)
            Padding(
              padding: const EdgeInsets.only(top: AiroSpacing.sm),
              child: Text(step),
            ),
          const SizedBox(height: AiroSpacing.lg),
          AppButton(
            label: 'Replace with another catalog meal',
            variant: AppButtonVariant.secondary,
            isExpanded: true,
            onPressed: () => _replace(context, ref, meal),
          ),
        ],
      ),
    );
  }

  Future<void> _replace(
    BuildContext context,
    WidgetRef ref,
    PlannedMeal meal,
  ) async {
    final session = ref.read(anyaSessionProvider);
    final profile = session.profile;
    if (profile == null) return;
    final options = eligibleCatalogMeals(
      profile: profile,
      catalog: ref.read(anyaCatalogProvider),
      importedRules: session.activeProgram?.rules ?? const DietRule(),
    ).where((candidate) => candidate.id != meal.meal.id).toList();
    if (options.isEmpty) return;
    final replacement = await showDialog<CatalogMeal>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace meal'),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: ListView(
            children: [
              for (final candidate in options)
                ListTile(
                  title: Text(candidate.name),
                  subtitle: Text(
                    '${candidate.nutrition.calories} kcal · ${candidate.cookTimeMinutes} min',
                  ),
                  onTap: () => Navigator.pop(context, candidate),
                ),
            ],
          ),
        ),
      ),
    );
    if (replacement == null) return;
    await ref
        .read(anyaSessionProvider.notifier)
        .swapPlannedMeal(plannedMealId: meal.id, replacement: replacement);
    if (context.mounted) context.pop();
  }
}
