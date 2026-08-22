class QuerySet {
  const QuerySet({
    required this.primary,
    required this.alternatives,
    required this.counterargument,
  });

  final String primary;
  final List<String> alternatives;
  final String counterargument;
}

class QueryGenerator {
  const QueryGenerator();

  QuerySet queriesFor(String question) {
    final q = question.trim();
    return QuerySet(
      primary: q,
      alternatives: [
        '$q benchmark',
        '$q memory requirements',
        '$q official documentation',
      ],
      counterargument: '$q limitations OR problems OR drawbacks',
    );
  }
}
