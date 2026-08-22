class ComparisonCell {
  const ComparisonCell({
    required this.subject,
    required this.criterion,
    required this.value,
    required this.sourceUrl,
  });

  final String subject;
  final String criterion;
  final String value;
  final String sourceUrl;
}

class DecisionRow {
  const DecisionRow({
    required this.subject,
    required this.coveredCriteria,
    required this.weightedScore,
    required this.contested,
  });

  final String subject;
  final int coveredCriteria;
  final double weightedScore;
  final bool contested;
}

List<ComparisonCell> comparisonMatrix({
  required List<String> subjects,
  required List<String> criteria,
  required List<(String text, String url)> claims,
}) {
  final cells = <ComparisonCell>[];
  for (final subject in subjects) {
    for (final criterion in criteria) {
      for (final claim in claims) {
        final text = claim.$1;
        if (_contains(text, subject) && _contains(text, criterion)) {
          cells.add(
            ComparisonCell(
              subject: subject,
              criterion: criterion,
              value: text,
              sourceUrl: claim.$2,
            ),
          );
          break;
        }
      }
    }
  }
  return cells;
}

List<double> criterionWeights(List<String> criteria) {
  return [
    for (final criterion in criteria)
      criterion.toLowerCase() == 'memory' ? 2.0 : 1.0,
  ];
}

List<DecisionRow> decide({
  required List<String> subjects,
  required List<ComparisonCell> cells,
  required List<String> criteria,
  required List<double> weights,
  required int conflicts,
}) {
  double weightFor(String criterion) {
    final index = criteria.indexOf(criterion);
    if (index < 0 || index >= weights.length) {
      return 1.0;
    }
    return weights[index];
  }

  final rows = [
    for (final subject in subjects)
      () {
        final seen = <String>{};
        var weightedScore = 0.0;
        var covered = 0;
        for (final cell in cells.where((entry) => entry.subject == subject)) {
          if (seen.add(cell.criterion)) {
            covered += 1;
            weightedScore += weightFor(cell.criterion);
          }
        }
        return DecisionRow(
          subject: subject,
          coveredCriteria: covered,
          weightedScore: weightedScore,
          contested: conflicts > 0 && covered > 0,
        );
      }(),
  ]..sort((a, b) => b.weightedScore.compareTo(a.weightedScore));
  return rows;
}

String matrixMarkdown(List<ComparisonCell> cells) {
  if (cells.isEmpty) {
    return '';
  }
  final lines = <String>[
    '## Comparison Matrix',
    '',
    '| Subject | Criterion | Finding | Source |',
    '| --- | --- | --- | --- |',
    for (final cell in cells)
      '| ${cell.subject} | ${cell.criterion} | ${cell.value} | ${cell.sourceUrl} |',
  ];
  return lines.join('\n');
}

bool _contains(String hay, String needle) {
  return hay.toLowerCase().contains(needle.toLowerCase());
}
