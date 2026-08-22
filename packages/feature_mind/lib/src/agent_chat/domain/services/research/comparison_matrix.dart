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
    required this.contested,
  });

  final String subject;
  final int coveredCriteria;
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

List<DecisionRow> decide({
  required List<String> subjects,
  required List<ComparisonCell> cells,
  required int conflicts,
}) {
  final rows = [
    for (final subject in subjects)
      DecisionRow(
        subject: subject,
        coveredCriteria: cells.where((cell) => cell.subject == subject).length,
        contested:
            conflicts > 0 && cells.any((cell) => cell.subject == subject),
      ),
  ]..sort((a, b) => b.coveredCriteria.compareTo(a.coveredCriteria));
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
