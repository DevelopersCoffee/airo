import '../entities/diet_program.dart';
import '../entities/enums.dart';
import '../entities/grocery_list.dart';
import '../entities/ingredient.dart';
import '../entities/weekly_plan.dart';

GroceryList groceryListFromWeeklyPlan(WeeklyPlan plan) {
  final buckets = <String, _Agg>{};
  for (final planned in plan.meals) {
    final factor = planned.servingFactor;
    for (final ingredient in planned.meal.ingredients) {
      final scaled = ingredient.scaled(factor);
      final key =
          '${scaled.aisle.name}:${scaled.name.toLowerCase()}:${scaled.unit}';
      final existing = buckets[key];
      if (existing == null) {
        buckets[key] = _Agg(scaled);
      } else {
        existing.quantity += scaled.quantity;
      }
    }
  }
  final lines =
      buckets.values
          .map(
            (agg) => GroceryLine(
              name: _titleCase(agg.ingredient.name),
              quantityLabel: _formatQuantity(agg.quantity, agg.ingredient.unit),
              aisle: agg.ingredient.aisle,
            ),
          )
          .toList()
        ..sort((a, b) {
          final aisle = a.aisle.index.compareTo(b.aisle.index);
          if (aisle != 0) return aisle;
          return a.name.compareTo(b.name);
        });
  return GroceryList(lines: lines);
}

/// PDF items that did not map to catalog ingredients stay as free-text lines.
GroceryList groceryListFromProgram(DietProgram program) {
  final lines = <GroceryLine>[];
  final seen = <String>{};
  for (final day in program.allDays) {
    for (final slot in day.meals) {
      for (final item in slot.items) {
        final key = item.name.toLowerCase();
        if (!seen.add(key)) continue;
        lines.add(
          GroceryLine(
            name: item.name,
            quantityLabel: item.quantityRaw,
            aisle: GroceryAisle.other,
            fromUnmappedPdf: true,
          ),
        );
      }
    }
  }
  return GroceryList(lines: lines);
}

/// Catalog grocery first; imported PDF items append when the name is new.
GroceryList mergeGroceryLists(GroceryList catalog, GroceryList imported) {
  final names = {for (final line in catalog.lines) line.name.toLowerCase()};
  return GroceryList(
    lines: [
      ...catalog.lines,
      for (final line in imported.lines)
        if (!names.contains(line.name.toLowerCase())) line,
    ],
  );
}

class _Agg {
  _Agg(this.ingredient) : quantity = ingredient.quantity;

  final Ingredient ingredient;
  double quantity;
}

String _formatQuantity(double quantity, String unit) {
  final rounded = quantity % 1 == 0
      ? quantity.toStringAsFixed(0)
      : quantity.toStringAsFixed(1);
  if (unit == 'count') return rounded;
  return '$rounded $unit';
}

String _titleCase(String value) {
  return value
      .split(' ')
      .map((part) {
        if (part.isEmpty) return part;
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}
