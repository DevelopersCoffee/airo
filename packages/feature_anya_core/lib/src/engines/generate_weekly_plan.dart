import '../entities/catalog_meal.dart';
import '../entities/diet_profile.dart';
import '../entities/diet_program.dart';
import '../entities/enums.dart';
import '../entities/weekly_plan.dart';

/// Catalog meals that match the household profile and optional imported avoids.
List<CatalogMeal> eligibleCatalogMeals({
  required DietProfile profile,
  required List<CatalogMeal> catalog,
  DietRule importedRules = const DietRule(),
}) {
  final extraAvoid = importedRules.avoidFoods.join(', ');
  final allergies = [
    profile.allergies,
    extraAvoid,
  ].where((part) => part.trim().isNotEmpty).join(', ');
  final eligible = catalog
      .where(
        (meal) => meal.isAllowedFor(
          userDiet: profile.dietType,
          allergies: allergies,
          dislikes: profile.dislikes,
        ),
      )
      .toList();
  eligible.sort((a, b) {
    final score = _moodScore(
      b,
      profile.moods,
    ).compareTo(_moodScore(a, profile.moods));
    if (score != 0) return score;
    if (profile.moods.contains(FoodMood.budgetFriendly)) {
      final cost = a.estimatedCost.compareTo(b.estimatedCost);
      if (cost != 0) return cost;
    }
    return a.id.compareTo(b.id);
  });
  return eligible;
}

/// Builds a weekly plan from the catalog. No calorie prescription — only
/// filtering, scoring, and serving-size scaling.
WeeklyPlan generateWeeklyPlan({
  required DietProfile profile,
  required List<CatalogMeal> catalog,
  required String weekStartIso,
  DietRule importedRules = const DietRule(),
}) {
  final eligible = eligibleCatalogMeals(
    profile: profile,
    catalog: catalog,
    importedRules: importedRules,
  );

  final pool = eligible.isEmpty && importedRules.avoidFoods.isEmpty
      ? catalog
      : eligible;
  if (pool.isEmpty) {
    return WeeklyPlan(
      weekStartIso: weekStartIso,
      profile: profile,
      meals: const [],
    );
  }
  final meals = <PlannedMeal>[];
  var index = 0;
  const slots = [MealType.lunch, MealType.dinner];
  for (final day in profile.cookingDays) {
    for (final slot in slots) {
      var candidate = pool[index % pool.length];
      index++;
      if (profile.weeklyBudget > 0) {
        final projected =
            meals.fold(0.0, (sum, m) => sum + m.estimatedCost) +
            candidate.estimatedCost *
                (profile.householdSize / candidate.servings);
        if (projected > profile.weeklyBudget) {
          final cheaper = pool.where(
            (m) => m.estimatedCost < candidate.estimatedCost,
          );
          if (cheaper.isNotEmpty) {
            candidate = cheaper.first;
          }
        }
      }
      meals.add(
        PlannedMeal(
          id: '${day.name}_${slot.name}_${candidate.id}',
          weekday: day,
          mealType: slot,
          meal: candidate,
          servings: profile.householdSize,
        ),
      );
    }
  }

  return WeeklyPlan(weekStartIso: weekStartIso, profile: profile, meals: meals);
}

/// Swap one generated slot. Keeps weekday, meal type, and servings.
WeeklyPlan replacePlannedMeal({
  required WeeklyPlan plan,
  required String plannedMealId,
  required CatalogMeal replacement,
}) {
  return WeeklyPlan(
    weekStartIso: plan.weekStartIso,
    profile: plan.profile,
    meals: [
      for (final meal in plan.meals)
        if (meal.id != plannedMealId)
          meal
        else
          PlannedMeal(
            id: '${meal.weekday.name}_${meal.mealType.name}_${replacement.id}',
            weekday: meal.weekday,
            mealType: meal.mealType,
            meal: replacement,
            servings: meal.servings,
          ),
    ],
  );
}

int _moodScore(CatalogMeal meal, Set<FoodMood> moods) {
  if (moods.isEmpty) return 0;
  return meal.moods.where(moods.contains).length;
}
