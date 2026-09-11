import '../entities/diet_program.dart';
import '../entities/enums.dart';

/// Second-pass repair after [DietPdfNormalizer.parseProgram].
///
/// Joins split name fragments when the concatenation appears in [originalText]
/// and drops rows whose name is only a meal-type label. Never invents units.
DietProgram repairImportedProgram({
  required DietProgram program,
  required String originalText,
}) {
  return program.copyWith(
    phases: [
      for (final phase in program.phases)
        phase.copyWith(
          days: [
            for (final day in phase.days)
              day.copyWith(
                meals: [
                  for (final slot in day.meals)
                    slot.copyWith(
                      items: _repairItems(slot.items, originalText),
                    ),
                ],
              ),
          ],
        ),
    ],
  );
}

final _mealTypeLabels = {
  for (final type in MealType.values) _fold(type.label),
  'mid morning',
  'mid-morning',
};

List<FoodItem> _repairItems(List<FoodItem> items, String originalText) {
  final withoutLabels = [
    for (final item in items)
      if (!_isMealTypeLabel(item.name)) item,
  ];
  if (withoutLabels.length <= 1) return withoutLabels;

  final repaired = <FoodItem>[];
  var index = 0;
  while (index < withoutLabels.length) {
    var end = withoutLabels.length - 1;
    var merged = false;
    while (end > index) {
      final window = withoutLabels.sublist(index, end + 1);
      final name = _joinedName(window, originalText);
      if (name != null) {
        repaired.add(_mergedItem(window, name));
        index = end + 1;
        merged = true;
        break;
      }
      end--;
    }
    if (!merged) {
      repaired.add(withoutLabels[index]);
      index++;
    }
  }
  return repaired;
}

bool _isMealTypeLabel(String name) => _mealTypeLabels.contains(_fold(name));

String? _joinedName(List<FoodItem> window, String originalText) {
  final pattern = [
    for (final item in window) RegExp.escape(item.name.trim()),
  ].join(r'\s*');
  final match = RegExp(pattern, caseSensitive: false).firstMatch(originalText);
  if (match == null) return null;
  return match.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim();
}

FoodItem _mergedItem(List<FoodItem> window, String name) {
  var quantityRaw = '';
  var quantityUninterpreted = false;
  for (final item in window) {
    if (item.quantityRaw.trim().isNotEmpty) {
      quantityRaw = item.quantityRaw;
    }
    quantityUninterpreted = quantityUninterpreted || item.quantityUninterpreted;
  }
  return FoodItem(
    name: name,
    quantityRaw: quantityRaw,
    quantityUninterpreted: quantityUninterpreted,
  );
}

String _fold(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
