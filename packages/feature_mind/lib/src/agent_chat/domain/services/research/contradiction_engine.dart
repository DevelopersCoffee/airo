import 'claim_extractor.dart';
import 'source_manager.dart';

class ClaimConflict {
  const ClaimConflict({
    required this.left,
    required this.right,
    required this.reasons,
  });

  final ResearchClaim left;
  final ResearchClaim right;
  final List<String> reasons;

  String get explanation =>
      '${left.text} vs ${right.text} (${reasons.join(', ')})';
}

/// Conflicting claims stay visible with reasons. The engine does not pick a
/// winner.
List<ClaimConflict> explainContradictions(
  List<ResearchClaim> claims,
  List<SourceDocument> documents,
) {
  final byUrl = {for (final document in documents) document.url: document};
  final supported = claims
      .where((claim) => claim.status == ClaimSupport.supported)
      .toList(growable: false);
  final conflicts = <ClaimConflict>[];
  for (var i = 0; i < supported.length; i++) {
    for (var j = i + 1; j < supported.length; j++) {
      final reasons = _reasons(supported[i], supported[j], byUrl);
      if (reasons.isEmpty) {
        continue;
      }
      conflicts.add(
        ClaimConflict(
          left: supported[i],
          right: supported[j],
          reasons: reasons,
        ),
      );
    }
  }
  return conflicts;
}

List<String> _reasons(
  ResearchClaim left,
  ResearchClaim right,
  Map<String, SourceDocument> byUrl,
) {
  if (_topicOverlap(left.text, right.text).isEmpty) {
    return const [];
  }
  final leftNums = _numbers(left.text);
  final rightNums = _numbers(right.text);
  if (leftNums.isEmpty ||
      rightNums.isEmpty ||
      leftNums.difference(rightNums).isEmpty &&
          rightNums.difference(leftNums).isEmpty) {
    return const [];
  }
  final reasons = <String>['different result'];
  final leftYear = _year(byUrl[left.sourceUrl]?.publishedAt);
  final rightYear = _year(byUrl[right.sourceUrl]?.publishedAt);
  if (leftYear != null && rightYear != null && leftYear != rightYear) {
    reasons.add('different date');
  }
  if (_hardwareClass(left.text) != _hardwareClass(right.text) &&
      _hardwareClass(left.text) != _Hardware.unknown &&
      _hardwareClass(right.text) != _Hardware.unknown) {
    reasons.add('different hardware');
  }
  return reasons;
}

Set<String> _topicOverlap(String left, String right) {
  final leftTokens = _tokens(left);
  leftTokens.retainAll(_tokens(right));
  return leftTokens;
}

Set<String> _tokens(String text) {
  const stop = {
    'uses',
    'use',
    'the',
    'and',
    'from',
    'with',
    'on',
    'of',
    'a',
    'an',
    'gb',
    'ram',
    'is',
  };
  return text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.length >= 4 && !stop.contains(token))
      .toSet();
}

Set<int> _numbers(String text) {
  return RegExp(
    r'\d+',
  ).allMatches(text).map((match) => int.parse(match.group(0)!)).toSet();
}

int? _year(String? iso) {
  if (iso == null || iso.length < 4) {
    return null;
  }
  return int.tryParse(iso.substring(0, 4));
}

enum _Hardware { mobile, desktop, unknown }

_Hardware _hardwareClass(String text) {
  final lower = text.toLowerCase();
  const mobile = ['mobile', 'phone', 'pixel', 'android', 'snapdragon'];
  const desktop = ['desktop', 'workstation', 'server', 'cuda', 'a100'];
  if (mobile.any(lower.contains)) {
    return _Hardware.mobile;
  }
  if (desktop.any(lower.contains)) {
    return _Hardware.desktop;
  }
  return _Hardware.unknown;
}
