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
  final glued = [
    for (final item in window) item.name.trim(),
  ].join().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  if (glued.length < 2) return null;
  final hay = originalText.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  if (!hay.contains(glued)) return null;
  return _reconstructName(window);
}

/// 1–2 character fragments glue onto the previous word (`T`+`ea` → tea).
String _reconstructName(List<FoodItem> window) {
  final words = <String>[];
  var current = window.first.name.trim();
  for (var i = 1; i < window.length; i++) {
    final fragment = window[i].name.trim();
    if (fragment.length <= 2) {
      if (current.length > 2) {
        words.add(current);
        current = fragment.toLowerCase();
      } else {
        current = '$current${fragment.toLowerCase()}';
      }
    } else {
      if (current.isNotEmpty) words.add(current);
      current = fragment;
    }
  }
  if (current.isNotEmpty) words.add(current);
  return words.join(' ');
}

FoodItem _mergedItem(List<FoodItem> window, String name) {
  FoodItem? withQuantity;
  for (final item in window) {
    if (item.quantityRaw.trim().isNotEmpty) withQuantity = item;
  }
  return FoodItem(
    name: name,
    quantityRaw: withQuantity?.quantityRaw ?? '',
    quantityUninterpreted:
        withQuantity?.quantityUninterpreted ??
        window.every((item) => item.quantityUninterpreted),
  );
}

String _fold(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
