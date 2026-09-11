import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:test/test.dart';

void main() {
  test('seed catalog has twenty meals covering vegan through meat', () {
    final catalog = seedMealCatalog();
    expect(catalog, hasLength(20));
    expect(catalog.any((m) => m.diet == DietType.vegan), isTrue);
    expect(catalog.any((m) => m.diet == DietType.vegetarian), isTrue);
    expect(catalog.any((m) => m.diet == DietType.pescatarian), isTrue);
    expect(catalog.any((m) => m.diet == DietType.none), isTrue);
    expect(catalog.every((m) => m.ingredients.isNotEmpty), isTrue);
  });
}
