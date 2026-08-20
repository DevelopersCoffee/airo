/// Code-based diet-agent evals: constraint checks on model output.
///
/// Does not supply meals. Used by tests and by a single compact-model retry.
class DietPlanOutputEval {
  const DietPlanOutputEval._();

  static final _dayHeader = RegExp(
    r'(?:^|\n)\s*\**\s*Day\s*(\d+)\b',
    caseSensitive: false,
  );

  static List<int> dayNumbers(String output) {
    return _dayHeader
        .allMatches(output)
        .map((match) => int.tryParse(match.group(1)!))
        .whereType<int>()
        .toList(growable: false);
  }

  static int dayCount(String output) => dayNumbers(output).length;

  static bool hasRequestedDays(String output, int? days) {
    if (days == null || days < 1) return true;
    final numbers = dayNumbers(output).toSet();
    for (var day = 1; day <= days; day++) {
      if (!numbers.contains(day)) return false;
    }
    return !numbers.any((day) => day > days);
  }

  static List<String> dayBodies(String output) {
    final matches = _dayHeader.allMatches(output).toList();
    if (matches.isEmpty) return const [];
    final bodies = <String>[];
    for (var i = 0; i < matches.length; i++) {
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : output.length;
      bodies.add(_normalizeMeals(output.substring(start, end)));
    }
    return bodies;
  }

  static bool allDaysRepeatTheSameMeals(String output) {
    final bodies = dayBodies(output).where((body) => body.isNotEmpty).toList();
    if (bodies.length < 2) return false;
    return bodies.toSet().length == 1;
  }

  static bool containsPeanut(String output) => RegExp(
    r'\bpeanuts?\b|peanut butter',
    caseSensitive: false,
  ).hasMatch(output);

  static String _normalizeMeals(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
