import 'package:flutter/foundation.dart';

import 'capability_models.dart';

/// A context in the hypergraph.
///
/// [opCount] and [itemCount] differ and both are shown: 38 items took 1,204
/// ops to reach. The gap is what makes the log's existence visible.
@immutable
class MindContext {
  const MindContext({
    required this.id,
    required this.label,
    required this.itemCount,
    required this.opCount,
    required this.openedAtMs,
    required this.safetyClass,
  });

  final String id;

  /// Includes the leading `#`. Surfaces render this verbatim.
  final String label;
  final int itemCount;
  final int opCount;
  final int openedAtMs;
  final CapabilitySafetyClass safetyClass;

  @override
  bool operator ==(Object other) =>
      other is MindContext &&
      other.id == id &&
      other.label == label &&
      other.itemCount == itemCount &&
      other.opCount == opCount &&
      other.openedAtMs == openedAtMs &&
      other.safetyClass == safetyClass;

  @override
  int get hashCode =>
      Object.hash(id, label, itemCount, opCount, openedAtMs, safetyClass);
}

/// An edge in the hypergraph. Undirected: linking A to B links B to A.
///
/// Equality ignores direction so the graph cannot hold the same edge twice,
/// which would double-count it in the survival preview.
@immutable
class ContextLink {
  const ContextLink(this.fromId, this.toId);

  final String fromId;
  final String toId;

  @override
  bool operator ==(Object other) =>
      other is ContextLink &&
      ((other.fromId == fromId && other.toId == toId) ||
          (other.fromId == toId && other.toId == fromId));

  @override
  int get hashCode => fromId.hashCode ^ toId.hashCode;
}
