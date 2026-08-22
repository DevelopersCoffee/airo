import 'package:core_domain/core_domain.dart';
import 'package:meta/meta.dart';

@immutable
class GraphIngestContext {
  const GraphIngestContext({
    required this.text,
    required this.graph,
    this.threadId = '',
    this.turnRevision = '',
  });

  final String text;
  final EntityGraph graph;
  final String threadId;
  final String turnRevision;
}
