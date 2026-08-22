import '../prompts/prompt.dart';
import 'scalar_constraint_kind.dart';

/// Removes superseded quantitative tokens from chat history before prefill.
///
/// Small GGUF models attend to earlier "7 day" tokens even when the latest
/// user turn says "3 days". True KV-cache eviction is engine-specific; this
/// is the portable equivalent used on every backend: the model never
/// tokenizes the old value.
class PromptInertiaGuard {
  const PromptInertiaGuard({this.kinds = const []});

  final List<ScalarConstraintKind> kinds;

  static const defaults = PromptInertiaGuard();

  List<ScalarConstraintKind> get _kinds =>
      kinds.isEmpty ? ScalarConstraintKind.defaults : kinds;

  /// Latest declared value per kind in [currentUserMessage].
  Map<String, int> latestValues(String currentUserMessage) {
    final values = <String, int>{};
    for (final kind in _kinds) {
      final value = kind.parseLatest(currentUserMessage);
      if (value != null) values[kind.id] = value;
    }
    return values;
  }

  List<Prompt> revise({
    required List<Prompt> history,
    required String currentUserMessage,
  }) {
    final latest = latestValues(currentUserMessage);
    if (latest.isEmpty) return history;

    return [
      for (final turn in history)
        Prompt(
          role: turn.role,
          content: _reviseContent(turn, latest),
          name: turn.name,
        ),
    ];
  }

  String maskText(String text, String currentUserMessage) {
    final latest = latestValues(currentUserMessage);
    if (latest.isEmpty) return text;
    return _maskScalars(text, latest);
  }

  String _reviseContent(Prompt turn, Map<String, int> latest) {
    if (turn.role == PromptRole.system) return turn.content;
    if (turn.role == PromptRole.user) {
      return _maskScalars(turn.content, latest);
    }
    if (_containsSupersededValue(turn.content, latest)) {
      final labels = latest.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      return '[Prior answer superseded ($labels). Do not copy it.]';
    }
    return turn.content;
  }

  String _maskScalars(String text, Map<String, int> latest) {
    var result = text;
    for (final kind in _kinds) {
      final current = latest[kind.id];
      if (current == null) continue;
      result = result.replaceAllMapped(kind.pattern, (match) {
        final value = int.tryParse(match.group(1)!);
        if (value == null || value == current) return match.group(0)!;
        return '';
      });
    }
    return result.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  bool _containsSupersededValue(String text, Map<String, int> latest) {
    for (final kind in _kinds) {
      final current = latest[kind.id];
      if (current == null) continue;
      for (final match in kind.pattern.allMatches(text)) {
        final value = int.tryParse(match.group(1)!);
        if (value != null && value != current) return true;
      }
    }
    return false;
  }
}
