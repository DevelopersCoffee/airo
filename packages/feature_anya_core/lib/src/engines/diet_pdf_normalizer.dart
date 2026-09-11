import '../entities/diet_program.dart';
import '../entities/document.dart';
import '../entities/enums.dart';

/// Heuristic PDF normalizer. Never invents units — `1k` stays `1k`.
class DietPdfNormalizer {
  const DietPdfNormalizer();

  PageClass classifyPage(String rawText) {
    final text = rawText.toLowerCase();
    if (text.contains('locked') || text.contains('subscribe to view')) {
      return PageClass.lockedContent;
    }
    if (text.contains('foods to include') ||
        (text.contains('include') && text.contains('millet'))) {
      return PageClass.foodsToInclude;
    }
    if (text.contains('foods to avoid') ||
        text.contains('do not eat') ||
        text.contains('avoid fried')) {
      return PageClass.foodsToAvoid;
    }
    if (RegExp(r'\bday\s+\d+', caseSensitive: false).hasMatch(text) &&
        _timePattern.hasMatch(text)) {
      return PageClass.mealPlan;
    }
    if (text.contains('phase') &&
        (text.contains('detox') ||
            text.contains('anti-inflammatory') ||
            text.contains('fat burn'))) {
      return PageClass.phase;
    }
    if ((text.contains('age') && text.contains('height')) ||
        text.contains('food habit') ||
        text.contains('bmi')) {
      return PageClass.profile;
    }
    if (text.contains('guideline') || text.contains('dietary instruction')) {
      return PageClass.guidelines;
    }
    return PageClass.unknown;
  }

  DietProgram parseProgram({
    required String id,
    required String title,
    required List<ExtractedPdfPage> pages,
  }) {
    final classified = [
      for (final page in pages)
        DocumentPage(
          pageNumber: page.pageNumber,
          rawText: page.text,
          pageClass: classifyPage(page.text),
          confidence: page.hasTextLayer ? 0.8 : 0,
        ),
    ];
    final days = <DietDay>[];
    final allowed = <String>[];
    final avoided = <String>[];
    final guidelines = <String>[];

    for (final page in classified) {
      switch (page.pageClass) {
        case PageClass.mealPlan:
          days.addAll(_parseMealDays(page.rawText));
        case PageClass.foodsToInclude:
          allowed.addAll(_parseBulletFoods(page.rawText));
        case PageClass.foodsToAvoid:
          avoided.addAll(_parseBulletFoods(page.rawText));
        case PageClass.guidelines:
          guidelines.addAll(_parseGuidelineLines(page.rawText));
        case PageClass.profile:
        case PageClass.phase:
        case PageClass.lockedContent:
        case PageClass.unknown:
          break;
      }
    }

    days.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    return DietProgram(
      id: id,
      title: title,
      source: ProgramSource.imported,
      phases: [DietPhase(id: '${id}_phase', name: 'Imported plan', days: days)],
      rules: DietRule(allowedFoods: allowed, avoidFoods: avoided),
      guidelines: guidelines,
    );
  }

  ExtractionValidation validate({
    required List<ExtractedPdfPage> pages,
    required DietProgram program,
  }) {
    final classes = [for (final page in pages) classifyPage(page.text)];
    final uninterpreted = [
      for (final day in program.allDays)
        for (final slot in day.meals)
          for (final item in slot.items)
            if (item.quantityUninterpreted) item,
    ].length;
    return ExtractionValidation(
      profileDetected: classes.contains(PageClass.profile),
      mealDaysDetected: program.allDays.length,
      mealTimingsDetected: program.allDays.any(
        (day) => day.meals.any((slot) => slot.time != null),
      ),
      restrictionsDetected:
          program.rules.avoidFoods.isNotEmpty ||
          program.rules.allowedFoods.isNotEmpty,
      includeListDetected: program.rules.allowedFoods.isNotEmpty,
      avoidListDetected: program.rules.avoidFoods.isNotEmpty,
      uninterpretedQuantities: uninterpreted,
    );
  }

  List<DietDay> _parseMealDays(String text) {
    final days = <DietDay>[];
    final dayBlocks = RegExp(
      r'DAY\s+(\d+)\s*([\s\S]*?)(?=DAY\s+\d+|$)',
      caseSensitive: false,
    ).allMatches(text);
    for (final block in dayBlocks) {
      final number = int.parse(block.group(1)!);
      final body = block.group(2) ?? '';
      days.add(DietDay(dayNumber: number, meals: _parseSlots(body)));
    }
    return days;
  }

  List<MealSlot> _parseSlots(String body) {
    final slots = <MealSlot>[];
    final matches = _timePattern.allMatches(body).toList();
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final start = match.end;
      final end = i + 1 < matches.length ? matches[i + 1].start : body.length;
      final time = _normalizeTime(match.group(0)!);
      final items = [
        for (final line in body.substring(start, end).split(RegExp(r'\r?\n')))
          if (line.trim().isNotEmpty && !_timePattern.hasMatch(line))
            _parseFoodLine(line.trim()),
      ];
      if (items.isEmpty) continue;
      slots.add(
        MealSlot(type: mealTypeForTime(time), time: time, items: items),
      );
    }
    return slots;
  }

  FoodItem _parseFoodLine(String line) {
    final cleaned = line.replaceAll(RegExp(r'[-–—]+'), ' ').trim();
    final leadingQty = RegExp(
      r'^((?:½|1/2|\d+(?:\.\d+)?)(?:\s*(?:k|tsp|tbsp|glass|cup|bowl))?)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (leadingQty != null) {
      return FoodItem(
        name: leadingQty.group(2)!.trim(),
        quantityRaw: leadingQty.group(1)!.trim(),
        quantityUninterpreted: _isUninterpreted(leadingQty.group(1)!),
      );
    }
    final trailingQty = RegExp(
      r'^(.+?)\s+((?:½|1/2|\d+(?:\.\d+)?)(?:\s*(?:k|tsp|tbsp|glass|cup|bowl))?)$',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (trailingQty != null) {
      return FoodItem(
        name: trailingQty.group(1)!.trim(),
        quantityRaw: trailingQty.group(2)!.trim(),
        quantityUninterpreted: _isUninterpreted(trailingQty.group(2)!),
      );
    }
    return FoodItem(
      name: cleaned,
      quantityRaw: '',
      quantityUninterpreted: true,
    );
  }

  bool _isUninterpreted(String raw) {
    final value = raw.toLowerCase().replaceAll(' ', '');
    return value.endsWith('k') || value.contains('½') || value.contains('1/2');
  }

  List<String> _parseBulletFoods(String text) {
    final foods = <String>[];
    for (final line in text.split(RegExp(r'\r?\n'))) {
      final trimmed = line.replaceFirst(RegExp(r'^[-•*\d.)\s]+'), '').trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();
      if (lower.contains('foods to include') ||
          lower.contains('foods to avoid') ||
          lower.contains('include') && trimmed.length < 24 ||
          lower.contains('avoid') && trimmed.length < 24) {
        continue;
      }
      foods.add(trimmed);
    }
    return foods;
  }

  List<String> _parseGuidelineLines(String text) {
    return [
      for (final line in text.split(RegExp(r'\r?\n')))
        if (line.trim().isNotEmpty && !line.toLowerCase().contains('guideline'))
          line.trim(),
    ];
  }

  String _normalizeTime(String raw) {
    final match = RegExp(
      r'(\d{1,2}):(\d{2})\s*(AM|PM)?',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return raw.trim();
    var hour = int.parse(match.group(1)!);
    final minute = match.group(2)!;
    final meridiem = match.group(3)?.toUpperCase();
    if (meridiem == 'PM' && hour < 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:$minute';
  }
}

final _timePattern = RegExp(
  r'\b\d{1,2}:\d{2}\s*(?:AM|PM)?\b',
  caseSensitive: false,
);

MealType mealTypeForTime(String time) {
  final hour = int.tryParse(time.split(':').first) ?? 12;
  if (hour < 9) return MealType.earlyMorning;
  if (hour < 11) return MealType.breakfast;
  if (hour < 12) return MealType.snack;
  if (hour < 16) return MealType.lunch;
  if (hour < 19) return MealType.evening;
  return MealType.dinner;
}
