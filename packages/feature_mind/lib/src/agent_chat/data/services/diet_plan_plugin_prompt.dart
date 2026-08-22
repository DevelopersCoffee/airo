import 'package:core_ai/core_ai.dart';

import 'assistant_chat_context_builder.dart';
import 'diet_plan_output_eval.dart';
import '../../domain/services/intent_parser.dart';

/// Builds a diet-plugin prompt from **user** constraints in the thread.
///
/// Does not supply meals. Compact local models copy the previous assistant
/// draft if it stays in context, so that draft is omitted.
class DietPlanPluginPrompt {
  const DietPlanPluginPrompt._();

  static final _dayCountPattern = RegExp(
    r'\b(\d{1,2})\s*-?\s*days?\b',
    caseSensitive: false,
  );
  static final _meatPattern = RegExp(
    r'\b(chicken|fish|salmon|mutton|lamb|beef|pork|prawn|shrimp|'
    r'turkey|bacon|ham|tuna|egg|eggs)\b',
    caseSensitive: false,
  );
  static final _dietPlanOutputPattern = RegExp(
    r'\bday\s*1\b',
    caseSensitive: false,
  );

  static bool applies({
    required String currentPrompt,
    required List<AssistantChatContextMessage> history,
  }) {
    if (_isSmallTalk(currentPrompt)) return false;
    if (_isUnrelatedStructuredIntent(currentPrompt)) return false;
    if (_looksLikeDietRequest(currentPrompt)) return true;
    if (!_inDietThread(history)) return false;
    return _looksLikeDietRefinement(currentPrompt) ||
        _looksLikeDietContinuation(currentPrompt) ||
        _looksLikeDietDeliveryAsk(currentPrompt) ||
        _looksLikeFullWeekAsk(currentPrompt);
  }

  static List<String> userConstraintLines({
    required String currentPrompt,
    required List<AssistantChatContextMessage> history,
  }) {
    final lines = <String>[];
    var dietThreadStarted = false;
    for (final message in history) {
      if (!message.isUser) continue;
      final text = message.text.trim();
      if (text.isEmpty) continue;
      if (_looksLikeDietRequest(text)) dietThreadStarted = true;
      if (!dietThreadStarted) continue;
      if (_isSmallTalk(text) || _isUnrelatedStructuredIntent(text)) continue;
      if (!_looksLikeDietRequest(text) &&
          !_looksLikeDietRefinement(text) &&
          !_looksLikeFullWeekAsk(text)) {
        continue;
      }
      lines.add(text);
    }
    final current = currentPrompt.trim();
    if (current.isNotEmpty &&
        !_isSmallTalk(current) &&
        !_isUnrelatedStructuredIntent(current) &&
        (dietThreadStarted || _looksLikeDietRequest(current)) &&
        (_looksLikeDietRequest(current) ||
            _looksLikeDietRefinement(current) ||
            _looksLikeFullWeekAsk(current))) {
      final alreadyIncluded = lines.any(
        (line) => _normalize(line) == _normalize(current),
      );
      if (!alreadyIncluded) lines.add(current);
    }
    return lines;
  }

  static List<AssistantChatContextMessage> contextHistory({
    required String currentPrompt,
    required List<AssistantChatContextMessage> history,
  }) {
    return userConstraintLines(currentPrompt: currentPrompt, history: history)
        .where((line) => _normalize(line) != _normalize(currentPrompt))
        .map((line) {
          return AssistantChatContextMessage(text: line, isUser: true);
        })
        .toList(growable: false);
  }

  static String modelUserPrompt({
    required String currentPrompt,
    required List<AssistantChatContextMessage> history,
  }) {
    final constraints = userConstraintLines(
      currentPrompt: currentPrompt,
      history: history,
    );
    if (isUnsafeDietRequest([...constraints, currentPrompt].join('\n'))) {
      return 'Do not write a meal plan. Airo is not a clinician. '
          'Refuse extreme restriction, fasting with medication, or advice '
          'that conflicts with a stated medical condition. Explain the risk '
          'briefly and tell the user to talk to a doctor or registered '
          'dietitian. Be calm and non-judgmental.';
    }
    if (constraints.isEmpty) return currentPrompt.trim();
    final days =
        parseDayCount(constraints.join(' ')) ??
        (_looksLikeFullWeekAsk(currentPrompt) ? 7 : null);
    final lastPlan = lastAssistantDietPlan(history);
    final promptConstraints = _promptConstraints(
      constraints,
      currentPrompt,
      days,
    );
    final continuePartial =
        _looksLikeDietContinuation(currentPrompt) &&
        !_looksLikeFullWeekAsk(currentPrompt) &&
        !_looksLikeDietDeliveryAsk(currentPrompt) &&
        lastPlan != null;
    if (continuePartial) {
      final lastDay = DietPlanOutputEval.dayNumbers(
        lastPlan,
      ).fold<int>(0, (max, day) => day > max ? day : max);
      final targetDays = days ?? (lastDay + 1);
      final nextDay = lastDay + 1;
      if (lastDay > 0 && nextDay <= targetDays) {
        return [
          'Continue the existing diet plan. Do not rewrite days already written.',
          'Constraints:',
          ContextCompiler.wrapAsData(
            promptConstraints.map((line) => '- $line').join('\n'),
          ),
          'Already written:',
          ContextCompiler.wrapAsData(lastPlan),
          'Write Day $nextDay through Day $targetDays. Stop after Day $targetDays.',
          'Use different dishes from the days already written.',
          'For each day list exactly four meals, one dish each: Breakfast, Lunch, Dinner, Snack.',
          'Everyday meal ideas for healthy adults are allowed. This is not medical advice. Do not refuse.',
        ].join('\n');
      }
    }
    final cancelledCounts = <int>{
      for (final line in constraints)
        ..._dayCountPattern
            .allMatches(line)
            .map((match) => int.tryParse(match.group(1)!))
            .whereType<int>(),
    }..remove(days);
    final dayRule = days == null
        ? 'Stop after the number of days the user asked for. Later day counts override earlier ones.'
        : [
            'The latest day count is $days. Title it a $days-day plan.',
            'Write Day 1 through Day $days. Stop after Day $days. Do not add Day ${days + 1}.',
            if (cancelledCounts.isNotEmpty)
              'The user replaced the ${cancelledCounts.map((count) => '$count-day').join(' / ')} request. Do not use that length in the title.',
          ].join(' ');
    return [
      'Write a new diet plan that satisfies every user constraint below.',
      'Constraints:',
      ContextCompiler.wrapAsData(
        promptConstraints.map((line) => '- $line').join('\n'),
      ),
      'Rules:',
      '- Rewrite the whole plan when constraints change. Do not copy a previous draft.',
      '- If they named a cuisine, every meal must be from that cuisine — do not keep old meals and add bread.',
      '- If they asked veg or vegetarian, include no meat, fish, or eggs. Dairy is OK unless they said vegan.',
      '- If they asked vegan, include no meat, fish, eggs, or dairy.',
      '- Each day must use different dishes.',
      '- $dayRule',
      '- Write every requested day in this reply. Do not stop after Day 1.',
      '- For each day list exactly four meals, one dish each: Breakfast, Lunch, Dinner, Snack.',
      '- Do not list several breakfasts or copy these rules as the meals.',
      '- Everyday meal ideas for healthy adults are allowed. This is not medical advice. Do not refuse.',
    ].join('\n');
  }

  /// Compact models continue a previous Day-1 template if it stays in context.
  static List<AssistantChatContextMessage> collapseAssistantDietDrafts(
    List<AssistantChatContextMessage> history,
  ) {
    return history
        .map((message) {
          if (message.isUser || !_looksLikeDietPlanOutput(message.text)) {
            return message;
          }
          return const AssistantChatContextMessage(
            text: 'Drafted a meal plan.',
            isUser: false,
          );
        })
        .toList(growable: false);
  }

  static int? parseDayCount(String text) {
    final matches = _dayCountPattern.allMatches(text).toList();
    if (matches.isNotEmpty) {
      return int.tryParse(matches.last.group(1)!);
    }
    if (_looksLikeFullWeekAsk(text)) return 7;
    return null;
  }

  static bool isUnsafeDietRequest(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('eating disorder') ||
        lower.contains('anorexia') ||
        lower.contains('bulimia')) {
      return true;
    }
    if (lower.contains('calorie') &&
        RegExp(r'\b(500|600|700|800)\b').hasMatch(lower)) {
      return true;
    }
    if (lower.contains('fast') &&
        (lower.contains('water') ||
            lower.contains('24-hour') ||
            lower.contains('24 hour'))) {
      return true;
    }
    if ((lower.contains('pregnant') || lower.contains('pregnancy')) &&
        (lower.contains('keto') || lower.contains('fast'))) {
      return true;
    }
    if ((lower.contains('kidney') || lower.contains('ckd')) &&
        (lower.contains('protein') || lower.contains('3g'))) {
      return true;
    }
    if ((lower.contains('insulin') || lower.contains('diabetic')) &&
        lower.contains('fast')) {
      return true;
    }
    return false;
  }

  static bool wantsVegetarian(Iterable<String> constraints) {
    final joined = constraints.join(' ').toLowerCase();
    if (RegExp(r'non[\s-]*veg').hasMatch(joined)) return false;
    return joined.contains('veg only') ||
        joined.contains('veg-only') ||
        joined.contains('vegetarian') ||
        joined.contains('vegan') ||
        RegExp(r'\bveg\b').hasMatch(joined);
  }

  static bool containsDisallowedMeat(String output) =>
      _meatPattern.hasMatch(output);

  static bool shouldRetryVegetarian({
    required String output,
    required Iterable<String> constraints,
  }) {
    return wantsVegetarian(constraints) && containsDisallowedMeat(output);
  }

  static bool shouldRetryPlan({
    required String output,
    required Iterable<String> constraints,
  }) {
    final joined = constraints.join(' ');
    if (isUnsafeDietRequest(joined)) return false;
    if (looksLikeModelRefusal(output)) return true;
    if (shouldRetryVegetarian(output: output, constraints: constraints)) {
      return true;
    }
    if (joined.toLowerCase().contains('peanut') &&
        DietPlanOutputEval.containsPeanut(output)) {
      return true;
    }
    final days = parseDayCount(joined);
    if (days != null && !DietPlanOutputEval.hasRequestedDays(output, days)) {
      return true;
    }
    return DietPlanOutputEval.allDaysRepeatTheSameMeals(output);
  }

  static String trimExtraDays(String output, int? days) {
    if (days == null || days < 1) return output.trim();
    final nextDay = RegExp(
      '(?:^|\\n)\\s*\\**\\s*Day\\s*${days + 1}\\b',
      caseSensitive: false,
    );
    final match = nextDay.firstMatch(output);
    if (match == null || match.start <= 0) return output.trim();
    return output.substring(0, match.start).trim();
  }

  /// Compact models copy an earlier "N-day" title after the user shortens
  /// the plan. Fix the preamble; leave Day headers alone.
  static String alignPlanTitle(String output, int? days) {
    final trimmed = trimExtraDays(output, days);
    if (days == null || days < 1) return trimmed;
    final header = RegExp(
      r'(?:^|\n)\s*\**\s*Day\s*\d+\b',
      caseSensitive: false,
    );
    final match = header.firstMatch(trimmed);
    if (match == null) return _replaceWrongDuration(trimmed, days);
    final preamble = trimmed.substring(0, match.start);
    final body = trimmed.substring(match.start);
    return '${_replaceWrongDuration(preamble, days)}$body'.trim();
  }

  static List<String> _promptConstraints(
    List<String> constraints,
    String currentPrompt,
    int? days,
  ) {
    final lines = <String>[
      if (days != null)
        'Duration: $days days. Use this length; ignore earlier day counts.',
    ];
    for (final line in constraints) {
      if (_normalize(line) == _normalize(currentPrompt)) {
        if (!_looksLikeDietDeliveryAsk(line)) {
          lines.add(line);
        }
        continue;
      }
      final scrubbed = _stripWeekPhrases(
        PromptInertiaGuard.defaults.maskText(line, currentPrompt),
      );
      if (scrubbed.isEmpty) continue;
      lines.add(scrubbed);
    }
    return lines;
  }

  static String _stripWeekPhrases(String line) {
    var text = line.replaceAll(
      RegExp(
        r'\b((the\s+)?(whole|full|entire|complete)\s+week|all\s+(7|seven)\s+days|all days)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    if (text == line) return line;
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    text = text
        .replaceAll(RegExp(r'\b(for|only|just)\b$', caseSensitive: false), '')
        .trim();
    if (text.toLowerCase() == 'make me a' ||
        text.toLowerCase() == 'make me a diet plan' ||
        text.toLowerCase() == 'diet plan') {
      return 'diet plan';
    }
    return text;
  }

  static String _replaceWrongDuration(String preamble, int days) {
    return preamble.replaceAllMapped(_dayCountPattern, (match) {
      final n = int.tryParse(match.group(1)!);
      if (n == days) return match.group(0)!;
      final token = match.group(0)!;
      if (token.contains('-')) return '$days-day';
      if (RegExp(r'days$', caseSensitive: false).hasMatch(token)) {
        return '$days days';
      }
      return '$days-day';
    });
  }

  static bool _inDietThread(List<AssistantChatContextMessage> history) {
    return history.any(
      (message) => message.isUser
          ? _looksLikeDietRequest(message.text)
          : _looksLikeDietPlanOutput(message.text),
    );
  }

  static String? lastAssistantDietPlan(
    List<AssistantChatContextMessage> history,
  ) {
    for (final message in history.reversed) {
      if (message.isUser) continue;
      if (_looksLikeDietPlanOutput(message.text)) return message.text.trim();
    }
    return null;
  }

  static bool looksLikeModelRefusal(String text) {
    final lower = text.toLowerCase();
    return lower.contains("can't assist") ||
        lower.contains('cannot assist') ||
        lower.contains("can't help with") ||
        lower.contains('cannot help with') ||
        lower.contains('i am not able to') ||
        lower.contains("i'm not able to") ||
        (lower.contains("i'm sorry") && lower.contains('cannot'));
  }

  static bool _looksLikeDietContinuation(String text) {
    final lower = text.trim().toLowerCase();
    return RegExp(
      r'\b(next day|day\s*\d+|continue|keep going|remaining days|'
      r'rest of (the )?(days|plan|week)|and the rest|next days?)\b',
    ).hasMatch(lower);
  }

  static bool _looksLikeFullWeekAsk(String text) {
    final lower = text.trim().toLowerCase();
    return RegExp(
      r'\b((the\s+)?(whole|full|entire|complete)\s+week|'
      r'all\s+(7|seven)\s+days|all days|full plan|complete plan)\b',
    ).hasMatch(lower);
  }

  static bool _looksLikeDietDeliveryAsk(String text) {
    final lower = text.trim().toLowerCase().replaceAll(RegExp(r'[!.?]+$'), '');
    const exact = {
      'give me',
      'give it',
      'show me',
      'show it',
      'send it',
      'write it',
      'write them',
      'the plan',
      'please',
    };
    if (exact.contains(lower)) return true;
    if (lower.contains('full response') ||
        lower.contains("can't see") ||
        lower.contains('cant see') ||
        lower.contains('incomplete')) {
      return true;
    }
    return RegExp(
      r'^(give|show|send|write)\s+(me\s+)?(it|that|them|the plan)?$',
    ).hasMatch(lower);
  }

  static bool _looksLikeDietRequest(String text) {
    if (IntentParser.parse(text).type == IntentType.createDietPlan) {
      return true;
    }
    final lower = text.toLowerCase();
    return lower.contains('meal plan') ||
        lower.contains('food plan') ||
        lower.contains('diet plan') ||
        lower.contains('diet chart') ||
        lower.contains('meal chart') ||
        (lower.contains('menu') &&
            (lower.contains('indian') || lower.contains('veg')));
  }

  static bool _looksLikeDietRefinement(String text) {
    if (_looksLikeDietRequest(text)) return true;
    if (_isSmallTalk(text) || _isUnrelatedStructuredIntent(text)) return false;
    final lower = text.toLowerCase();
    return lower.contains('menu') ||
        lower.contains('calorie') ||
        lower.contains('allerg') ||
        lower.contains('protein') ||
        lower.contains('cuisine') ||
        lower.contains('breakfast') ||
        lower.contains('indian') ||
        lower.contains('vegan') ||
        lower.contains('vegetarian') ||
        RegExp(r'\bveg\b').hasMatch(lower) ||
        _looksLikeFullWeekAsk(lower) ||
        _dayCountPattern.hasMatch(lower);
  }

  static bool _looksLikeDietPlanOutput(String text) {
    final lower = text.toLowerCase();
    return _dietPlanOutputPattern.hasMatch(lower) &&
        (lower.contains('breakfast') || lower.contains('lunch'));
  }

  static bool _isSmallTalk(String text) {
    final lower = text.trim().toLowerCase().replaceAll(RegExp(r'[!.]+$'), '');
    const exact = {
      'hi',
      'hello',
      'hey',
      'yo',
      'sup',
      'thanks',
      'thank you',
      'ok',
      'okay',
      'bye',
      'good morning',
      'good evening',
      'good night',
    };
    if (exact.contains(lower)) return true;
    if (RegExp(r'^\d+\s*[+\-*/]\s*\d+$').hasMatch(lower)) return true;
    return false;
  }

  static bool _isUnrelatedStructuredIntent(String text) {
    final type = IntentParser.parse(text).type;
    return type != IntentType.unknown && type != IntentType.createDietPlan;
  }

  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
