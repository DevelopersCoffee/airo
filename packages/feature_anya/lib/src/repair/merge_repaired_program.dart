import 'package:feature_anya_core/feature_anya_core.dart';

/// Keep heuristic [id]/[source] and restore [FoodItem.quantityRaw] the model dropped.
DietProgram mergeRepairedProgram({
  required DietProgram heuristic,
  required DietProgram repaired,
}) {
  return repaired.copyWith(
    id: heuristic.id,
    source: heuristic.source,
    phases: [
      for (
        var phaseIndex = 0;
        phaseIndex < repaired.phases.length;
        phaseIndex++
      )
        _mergePhase(
          heuristic.phases.length > phaseIndex
              ? heuristic.phases[phaseIndex]
              : null,
          repaired.phases[phaseIndex],
        ),
    ],
  );
}

DietPhase _mergePhase(DietPhase? heuristic, DietPhase repaired) {
  if (heuristic == null) return repaired;
  return repaired.copyWith(
    days: [
      for (final day in repaired.days)
        _mergeDay(_dayByNumber(heuristic, day.dayNumber), day),
    ],
  );
}

DietDay? _dayByNumber(DietPhase phase, int dayNumber) {
  for (final day in phase.days) {
    if (day.dayNumber == dayNumber) return day;
  }
  return null;
}

DietDay _mergeDay(DietDay? heuristic, DietDay repaired) {
  if (heuristic == null) return repaired;
  return repaired.copyWith(
    meals: [
      for (var i = 0; i < repaired.meals.length; i++)
        _mergeSlot(
          _heuristicSlot(heuristic, repaired.meals[i], i),
          repaired.meals[i],
        ),
    ],
  );
}

MealSlot? _heuristicSlot(DietDay day, MealSlot repaired, int index) {
  final byTime = [
    for (final slot in day.meals)
      if (repaired.time != null && slot.time == repaired.time) slot,
  ];
  if (byTime.length == 1) return byTime.first;
  final byType = [
    for (final slot in day.meals)
      if (slot.type == repaired.type) slot,
  ];
  if (byType.length == 1) return byType.first;
  if (index < day.meals.length) return day.meals[index];
  return null;
}

MealSlot _mergeSlot(MealSlot? heuristic, MealSlot repaired) {
  if (heuristic == null) return repaired;
  return repaired.copyWith(
    items: [
      for (var i = 0; i < repaired.items.length; i++)
        _mergeFood(heuristic.items, repaired.items[i], i),
    ],
  );
}

FoodItem _mergeFood(
  List<FoodItem> heuristicItems,
  FoodItem repaired,
  int index,
) {
  if (repaired.quantityRaw.trim().isNotEmpty) return repaired;
  final byName = [
    for (final item in heuristicItems)
      if (_fold(item.name) == _fold(repaired.name)) item,
  ];
  final source = byName.length == 1
      ? byName.first
      : (index < heuristicItems.length ? heuristicItems[index] : null);
  if (source == null || source.quantityRaw.trim().isEmpty) return repaired;
  return repaired.copyWith(
    quantityRaw: source.quantityRaw,
    quantityUninterpreted: source.quantityUninterpreted,
  );
}

String _fold(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
