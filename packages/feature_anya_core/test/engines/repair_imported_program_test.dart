import 'dart:io';

import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:test/test.dart';

void main() {
  test('joins Green/T/ea and drops Dinner using original page text', () {
    const program = DietProgram(
      id: 'p1',
      title: 'Clinic',
      source: ProgramSource.imported,
      phases: [
        DietPhase(
          id: 'ph',
          name: 'Imported',
          days: [
            DietDay(
              dayNumber: 1,
              meals: [
                MealSlot(
                  type: MealType.evening,
                  time: '17:30',
                  items: [
                    FoodItem(name: 'Green', quantityRaw: ''),
                    FoodItem(name: 'T', quantityRaw: ''),
                    FoodItem(name: 'ea', quantityRaw: '1 cup'),
                    FoodItem(name: 'Dinner', quantityRaw: ''),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final repaired = repairImportedProgram(
      program: program,
      originalText: File(
        'test/fixtures/green_tea_split.txt',
      ).readAsStringSync(),
    );

    expect(repaired.id, 'p1');
    expect(repaired.source, ProgramSource.imported);
    expect(repaired.allDays.single.meals.single.items, [
      const FoodItem(name: 'Green tea', quantityRaw: '1 cup'),
    ]);
  });

  test('joins newline-split Green/T/ea the way PDF extract arrives', () {
    const program = DietProgram(
      id: 'p1',
      title: 'Clinic',
      source: ProgramSource.imported,
      phases: [
        DietPhase(
          id: 'ph',
          name: 'Imported',
          days: [
            DietDay(
              dayNumber: 1,
              meals: [
                MealSlot(
                  type: MealType.evening,
                  time: '17:30',
                  items: [
                    FoodItem(
                      name: 'Green',
                      quantityRaw: '',
                      quantityUninterpreted: true,
                    ),
                    FoodItem(
                      name: 'T',
                      quantityRaw: '',
                      quantityUninterpreted: true,
                    ),
                    FoodItem(name: 'ea', quantityRaw: '1 cup'),
                    FoodItem(
                      name: 'Dinner',
                      quantityRaw: '',
                      quantityUninterpreted: true,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final repaired = repairImportedProgram(
      program: program,
      originalText: '''
DAY 1
17:30 Evening
Green
T
ea 1 cup
Dinner
''',
    );

    expect(repaired.allDays.single.meals.single.items, [
      const FoodItem(name: 'Green tea', quantityRaw: '1 cup'),
    ]);
  });

  test('keeps 1k on the day-7 poha fixture', () {
    final text = File('test/fixtures/day7_meal_plan.txt').readAsStringSync();
    const normalizer = DietPdfNormalizer();
    final parsed = normalizer.parseProgram(
      id: 'anti_inflammatory',
      title: 'Anti-inflammatory',
      pages: [ExtractedPdfPage(pageNumber: 1, text: text)],
    );
    final repaired = repairImportedProgram(program: parsed, originalText: text);
    final poha = repaired.allDays.single.meals.first.items.first;
    expect(poha.name.toLowerCase(), 'veg poha');
    expect(poha.quantityRaw, '1k');
  });
}
