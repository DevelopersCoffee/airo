import '../entities/diet_program.dart';
import '../entities/enums.dart';

/// Edit, replace, or remove one food line in an imported program.
/// Pass [replacement] as null to remove [from].
DietProgram editProgramFoodItem({
  required DietProgram program,
  required int dayNumber,
  required MealType mealType,
  required String? time,
  required FoodItem from,
  FoodItem? replacement,
}) {
  return program.copyWith(
    phases: [
      for (final phase in program.phases)
        phase.copyWith(
          days: [
            for (final day in phase.days)
              if (day.dayNumber != dayNumber)
                day
              else
                day.copyWith(
                  meals: [
                    for (final slot in day.meals)
                      if (slot.type != mealType || slot.time != time)
                        slot
                      else
                        slot.copyWith(
                          items: [
                            for (final item in slot.items)
                              if (item != from)
                                item
                              else if (replacement != null)
                                replacement,
                          ],
                        ),
                  ],
                ),
          ],
        ),
    ],
  );
}
