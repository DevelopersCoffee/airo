import 'dart:io';

import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:test/test.dart';

void main() {
  final normalizer = const DietPdfNormalizer();

  test('parses day 7 poha fixture without rewriting 1k', () {
    final text = File('test/fixtures/day7_meal_plan.txt').readAsStringSync();
    final program = normalizer.parseProgram(
      id: 'anti_inflammatory',
      title: 'Anti-inflammatory',
      pages: [ExtractedPdfPage(pageNumber: 1, text: text)],
    );

    expect(program.allDays, hasLength(1));
    final day = program.allDays.single;
    expect(day.dayNumber, 7);
    expect(day.meals, hasLength(3));

    final breakfast = day.meals[0];
    expect(breakfast.time, '10:00');
    expect(breakfast.type, MealType.breakfast);
    expect(breakfast.items[0].name.toLowerCase(), 'veg poha');
    expect(breakfast.items[0].quantityRaw, '1k');
    expect(breakfast.items[1].name.toLowerCase(), contains('buttermilk'));
    expect(breakfast.items[1].quantityRaw, contains('½'));

    final snack = day.meals[1];
    expect(snack.time, '11:00');
    expect(snack.type, MealType.snack);
    expect(snack.items.single.name.toLowerCase(), 'citrus fruit');
    expect(snack.items.single.quantityRaw, '1');

    final lunch = day.meals[2];
    expect(lunch.time, '13:30');
    expect(lunch.type, MealType.lunch);
    expect(
      lunch.items.map((item) => item.name.toLowerCase()),
      containsAll(['paneer sabji', 'millet roti']),
    );
    expect(
      lunch.items
          .firstWhere((item) => item.name.toLowerCase() == 'paneer sabji')
          .quantityRaw,
      '1k',
    );
    expect(
      lunch.items
          .firstWhere((item) => item.name.toLowerCase() == 'millet roti')
          .quantityRaw,
      '1',
    );

    final json = day.toJson();
    expect(((json['meals'] as List).first as Map)['items'], isA<List>());
    final poha =
        (((json['meals'] as List).first as Map)['items'] as List).first as Map;
    expect(poha['quantityRaw'], '1k');
  });

  test('extracts include and avoid lists as rules', () {
    final include = File(
      'test/fixtures/foods_to_include.txt',
    ).readAsStringSync();
    final avoid = File('test/fixtures/foods_to_avoid.txt').readAsStringSync();
    final program = normalizer.parseProgram(
      id: 'rules',
      title: 'Rules',
      pages: [
        ExtractedPdfPage(pageNumber: 1, text: include),
        ExtractedPdfPage(pageNumber: 2, text: avoid),
      ],
    );

    expect(
      program.rules.allowedFoods,
      containsAll(['millet', 'paneer', 'spinach']),
    );
    expect(
      program.rules.avoidFoods,
      containsAll(['fried foods', 'white rice']),
    );

    final validation = normalizer.validate(
      pages: [
        ExtractedPdfPage(pageNumber: 1, text: include),
        ExtractedPdfPage(pageNumber: 2, text: avoid),
      ],
      program: program,
    );
    expect(validation.includeListDetected, isTrue);
    expect(validation.avoidListDetected, isTrue);
    expect(validation.summaryLines, isNotEmpty);
  });

  test('empty text layer produces no days and a clear validation summary', () {
    final pages = [const ExtractedPdfPage(pageNumber: 1, text: '')];
    final program = normalizer.parseProgram(
      id: 'scan',
      title: 'Scan',
      pages: pages,
    );
    final validation = normalizer.validate(pages: pages, program: program);
    expect(program.allDays, isEmpty);
    expect(validation.mealDaysDetected, 0);
    expect(
      validation.summaryLines.single,
      'No structured diet content detected',
    );
  });
}
