import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:test/test.dart';

void main() {
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

  const from = FoodItem(name: 'veg poha', quantityRaw: '1k');

  test('edits a food name and keeps the raw quantity', () {
    final edited = editProgramFoodItem(
      program: program,
      dayNumber: 7,
      mealType: MealType.breakfast,
      time: '10:00',
      from: from,
      replacement: from.copyWith(name: 'vegetable poha'),
    );
    expect(
      edited.allDays.single.meals.single.items.first.name,
      'vegetable poha',
    );
    expect(edited.allDays.single.meals.single.items.first.quantityRaw, '1k');
  });

  test('replaces a food with a catalog name', () {
    final edited = editProgramFoodItem(
      program: program,
      dayNumber: 7,
      mealType: MealType.breakfast,
      time: '10:00',
      from: from,
      replacement: const FoodItem(
        name: 'Oats with Curd',
        quantityRaw: '1 bowl',
      ),
    );
    expect(
      edited.allDays.single.meals.single.items.first.name,
      'Oats with Curd',
    );
  });

  test('removes a food line', () {
    final edited = editProgramFoodItem(
      program: program,
      dayNumber: 7,
      mealType: MealType.breakfast,
      time: '10:00',
      from: from,
      replacement: null,
    );
    expect(edited.allDays.single.meals.single.items, hasLength(1));
    expect(edited.allDays.single.meals.single.items.single.name, 'buttermilk');
  });

  test('edits only the matching phase when a program has two phases', () {
    const twoPhase = DietProgram(
      id: 'imported',
      title: 'Imported',
      source: ProgramSource.imported,
      phases: [
        DietPhase(
          id: 'p1',
          name: 'Phase 1',
          days: [
            DietDay(
              dayNumber: 1,
              meals: [
                MealSlot(
                  type: MealType.lunch,
                  items: [FoodItem(name: 'dal', quantityRaw: '1 bowl')],
                ),
              ],
            ),
          ],
        ),
        DietPhase(
          id: 'p2',
          name: 'Phase 2',
          days: [
            DietDay(
              dayNumber: 7,
              meals: [
                MealSlot(
                  type: MealType.breakfast,
                  time: '10:00',
                  items: [FoodItem(name: 'veg poha', quantityRaw: '1k')],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final edited = editProgramFoodItem(
      program: twoPhase,
      dayNumber: 7,
      mealType: MealType.breakfast,
      time: '10:00',
      from: const FoodItem(name: 'veg poha', quantityRaw: '1k'),
      replacement: const FoodItem(name: 'vegetable poha', quantityRaw: '1k'),
    );
    expect(edited.phases, hasLength(2));
    expect(
      edited.phases.first.days.single.meals.single.items.single.name,
      'dal',
    );
    expect(
      edited.phases.last.days.single.meals.single.items.single.name,
      'vegetable poha',
    );
  });
}
