/// A quantitative fact in chat that a later user turn can replace.
///
/// Used by [PromptInertiaGuard] so small on-device models never see a
/// superseded value (e.g. "7 days") competing with the latest one ("3 days").
/// The runtime does not know diets or any other product domain — callers pass
/// the kinds they care about, or use [ScalarConstraintKind.defaults].
class ScalarConstraintKind {
  const ScalarConstraintKind({required this.id, required this.pattern});

  /// Stable id for logs and superseded-turn placeholders.
  final String id;

  /// Must capture the integer in group 1. Last match in a turn wins.
  final RegExp pattern;

  /// Calendar-length / plan-length requests: "7 day", "7-day", "3 days".
  static final dayCount = ScalarConstraintKind(
    id: 'day_count',
    pattern: RegExp(r'\b(\d{1,2})\s*-?\s*days?\b', caseSensitive: false),
  );

  static List<ScalarConstraintKind> get defaults => [dayCount];

  int? parseLatest(String text) {
    final matches = pattern.allMatches(text).toList();
    if (matches.isEmpty) return null;
    return int.tryParse(matches.last.group(1)!);
  }
}
