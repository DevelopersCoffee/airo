import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:test/test.dart';

void main() {
  const program = DietProgram(
    id: 'imported',
    title: 'Clinic',
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
                items: [FoodItem(name: 'veg poha', quantityRaw: '1k')],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  test('maps PDF day 7 onto Sunday when weekdays are missing', () {
    final sunday = DateTime(2026, 9, 13); // Sunday
    final day = todayProgramDay(program, sunday);
    expect(day?.dayNumber, 7);
    expect(day?.meals.single.items.single.name, 'veg poha');
  });

  test('returns null when no imported day maps onto today', () {
    final friday = DateTime(2026, 9, 11);
    expect(todayProgramDay(program, friday), isNull);
  });

  test('prefers an explicit weekday over day-number mapping', () {
    const withWeekday = DietProgram(
      id: 'imported',
      title: 'Clinic',
      source: ProgramSource.imported,
      phases: [
        DietPhase(
          id: 'p1',
          name: 'Phase',
          days: [
            DietDay(
              dayNumber: 1,
              weekday: Weekday.friday,
              meals: [
                MealSlot(
                  type: MealType.lunch,
                  items: [FoodItem(name: 'dal', quantityRaw: '1 bowl')],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final friday = DateTime(2026, 9, 11);
    expect(
      todayProgramDay(withWeekday, friday)?.meals.single.items.single.name,
      'dal',
    );
  });

  test('nextMealSlot picks the first remaining timed slot', () {
    const meals = [
      MealSlot(
        type: MealType.breakfast,
        time: '10:00',
        items: [FoodItem(name: 'poha', quantityRaw: '1k')],
      ),
      MealSlot(
        type: MealType.lunch,
        time: '13:30',
        items: [FoodItem(name: 'dal', quantityRaw: '1 bowl')],
      ),
    ];
    final lateMorning = DateTime(2026, 9, 11, 11, 0);
    expect(nextMealSlot(meals, lateMorning)?.items.single.name, 'dal');
  });
}
