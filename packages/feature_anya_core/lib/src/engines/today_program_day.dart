import '../entities/diet_program.dart';
import '../entities/enums.dart';
import '../entities/weekly_plan.dart';

/// Picks the imported day that should show on [now].
/// Prefers an explicit weekday, then dayNumber mapped onto Monday = day 1.
DietDay? todayProgramDay(DietProgram program, DateTime now) {
  if (program.allDays.isEmpty) return null;
  final weekday = Weekday.values[now.weekday - DateTime.monday];
  for (final day in program.allDays) {
    if (day.weekday == weekday) return day;
  }
  final index = now.weekday - DateTime.monday;
  for (final day in program.allDays) {
    if ((day.dayNumber - 1) % 7 == index) return day;
  }
  return null;
}

/// Catalog meals whose weekday matches [now]. Household week is a fallback.
List<PlannedMeal> todaysCatalogMeals(WeeklyPlan plan, DateTime now) {
  final weekday = Weekday.values[now.weekday - DateTime.monday];
  return [
    for (final meal in plan.meals)
      if (meal.weekday == weekday) meal,
  ];
}

/// Next slot at or after [now], else the first slot of the day.
MealSlot? nextMealSlot(List<MealSlot> meals, DateTime now) {
  if (meals.isEmpty) return null;
  final nowMinutes = now.hour * 60 + now.minute;
  MealSlot? upcoming;
  var upcomingMinutes = 24 * 60;
  for (final slot in meals) {
    final minutes = parseMealClockMinutes(slot.time);
    if (minutes == null) continue;
    if (minutes >= nowMinutes && minutes < upcomingMinutes) {
      upcoming = slot;
      upcomingMinutes = minutes;
    }
  }
  return upcoming ?? meals.first;
}

int? parseMealClockMinutes(String? time) {
  if (time == null) return null;
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time.trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}
