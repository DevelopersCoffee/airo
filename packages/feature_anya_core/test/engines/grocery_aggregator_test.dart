import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:test/test.dart';

void main() {
  test('aggregates catalog ingredients by aisle for a generated week', () {
    final profile = DietProfile(
      dietType: DietType.vegetarian,
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
    final grocery = groceryListFromWeeklyPlan(plan);

    expect(grocery.lines, isNotEmpty);
    expect(grocery.grouped.keys, isNotEmpty);
    expect(
      grocery.lines.every((line) => line.fromUnmappedPdf == false),
      isTrue,
    );
  });

  test('keeps unmapped PDF foods as free-text grocery lines', () {
    const program = DietProgram(
      id: 'imported',
      title: 'Imported',
      source: ProgramSource.imported,
      phases: [
        DietPhase(
          id: 'p1',
          name: 'Phase',
          days: [
            DietDay(
              dayNumber: 7,
              meals: [
                MealSlot(
                  type: MealType.breakfast,
                  time: '10:00',
                  items: [
                    FoodItem(name: 'veg poha', quantityRaw: '1k'),
                    FoodItem(name: 'buttermilk', quantityRaw: '½ glass'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final grocery = groceryListFromProgram(program);
    expect(grocery.lines, hasLength(2));
    expect(grocery.lines.first.fromUnmappedPdf, isTrue);
    expect(
      grocery.lines.map((l) => l.quantityLabel),
      containsAll(['1k', '½ glass']),
    );
  });

  test('merges catalog grocery with unmapped PDF foods', () {
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
    const program = DietProgram(
      id: 'imported',
      title: 'Imported',
      source: ProgramSource.imported,
      phases: [
        DietPhase(
          id: 'p1',
          name: 'Phase',
          days: [
            DietDay(
              dayNumber: 1,
              meals: [
                MealSlot(
                  type: MealType.breakfast,
                  items: [FoodItem(name: 'veg poha', quantityRaw: '1k')],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final merged = mergeGroceryLists(
      groceryListFromWeeklyPlan(plan),
      groceryListFromProgram(program),
    );
    expect(merged.lines.any((line) => line.fromUnmappedPdf), isTrue);
    expect(
      merged.lines.any((line) => line.name.toLowerCase() == 'veg poha'),
      isTrue,
    );
  });
}
