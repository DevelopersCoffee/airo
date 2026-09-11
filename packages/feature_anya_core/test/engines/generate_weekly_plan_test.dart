import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:test/test.dart';

void main() {
  test('filters vegan meals and scales servings to household size', () {
    final profile = DietProfile(
      dietType: DietType.vegan,
      householdSize: 4,
      weeklyBudget: 80,
      cookingDays: const [Weekday.monday, Weekday.wednesday],
      moods: const {FoodMood.budgetFriendly, FoodMood.speedy},
    );

    final plan = generateWeeklyPlan(
      profile: profile,
      catalog: seedMealCatalog(),
      weekStartIso: '2026-09-14',
    );

    expect(plan.meals, isNotEmpty);
    expect(plan.meals.every((m) => m.meal.diet == DietType.vegan), isTrue);
    expect(plan.meals.every((m) => m.servings == 4), isTrue);
    expect(plan.meals.map((m) => m.weekday).toSet(), {
      Weekday.monday,
      Weekday.wednesday,
    });
    expect(plan.totals.calories, greaterThan(0));
  });

  test('excludes meals that mention an allergy token', () {
    final profile = DietProfile(
      dietType: DietType.none,
      householdSize: 2,
      weeklyBudget: 100,
      cookingDays: const [Weekday.friday],
      moods: const {},
      allergies: 'peanuts',
    );

    final plan = generateWeeklyPlan(
      profile: profile,
      catalog: seedMealCatalog(),
      weekStartIso: '2026-09-14',
    );

    expect(plan.meals.any((m) => m.meal.id == 'veg_poha'), isFalse);
  });

  test('excludes catalog meals that match imported avoid foods', () {
    final profile = DietProfile(
      dietType: DietType.vegetarian,
      householdSize: 2,
      weeklyBudget: 200,
      cookingDays: const [
        Weekday.monday,
        Weekday.tuesday,
        Weekday.wednesday,
        Weekday.thursday,
      ],
      moods: const {FoodMood.proteinPacked},
    );
    const rules = DietRule(avoidFoods: ['paneer']);
    final plan = generateWeeklyPlan(
      profile: profile,
      catalog: seedMealCatalog(),
      weekStartIso: '2026-09-14',
      importedRules: rules,
    );

    expect(plan.meals, isNotEmpty);
    expect(
      plan.meals.any(
        (meal) => meal.meal.ingredients.any(
          (ingredient) => ingredient.name.toLowerCase().contains('paneer'),
        ),
      ),
      isFalse,
    );
  });

  test('replaces one planned meal and keeps the slot', () {
    final profile = DietProfile(
      dietType: DietType.vegan,
      householdSize: 2,
      weeklyBudget: 80,
      cookingDays: const [Weekday.monday],
      moods: const {FoodMood.speedy},
    );
    final plan = generateWeeklyPlan(
      profile: profile,
      catalog: seedMealCatalog(),
      weekStartIso: '2026-09-14',
    );
    final original = plan.meals.first;
    final replacement = eligibleCatalogMeals(
      profile: profile,
      catalog: seedMealCatalog(),
    ).firstWhere((meal) => meal.id != original.meal.id);

    final swapped = replacePlannedMeal(
      plan: plan,
      plannedMealId: original.id,
      replacement: replacement,
    );

    expect(swapped.meals.first.meal.id, replacement.id);
    expect(swapped.meals.first.weekday, original.weekday);
    expect(swapped.meals.first.mealType, original.mealType);
    expect(swapped.meals.first.servings, original.servings);
    expect(swapped.meals.length, plan.meals.length);
  });
}
