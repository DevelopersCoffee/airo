import 'package:flutter/foundation.dart';

/// The three projections. There are exactly three and they are one switcher —
/// see rule R03.
enum ProjectionKind { graph, timeline, search }

/// Where a projection is in its rebuild cycle.
///
/// Three projections can be in three different states for the same op, and the
/// inspector must say so rather than reporting one summary state.
enum ProjectionStatus { fresh, rebuilding, queued, stale }

/// A projection's state, including how long its last rebuild actually took.
///
/// [lastRebuildMs] is measured, not configured. Surfaces print it ("REBUILT
/// 3.1S AGO"), so a made-up number is a false claim on screen.
@immutable
class ProjectionState {
  const ProjectionState({
    required this.kind,
    required this.status,
    required this.lastRebuildMs,
    required this.opsProcessed,
    required this.opsTotal,
  });

  final ProjectionKind kind;
  final ProjectionStatus status;
  final int lastRebuildMs;

  /// Drives the rebuilding state's progress. A spinner without these two is a
  /// rule R04 violation.
  final int opsProcessed;
  final int opsTotal;

  @override
  bool operator ==(Object other) =>
      other is ProjectionState &&
      other.kind == kind &&
      other.status == status &&
      other.lastRebuildMs == lastRebuildMs &&
      other.opsProcessed == opsProcessed &&
      other.opsTotal == opsTotal;

  @override
  int get hashCode =>
      Object.hash(kind, status, lastRebuildMs, opsProcessed, opsTotal);
}

/// A search result, pointing back at the op it came from.
@immutable
class SearchHitRef {
  const SearchHitRef({
    required this.opSequence,
    required this.title,
    required this.snippet,
    required this.contextIds,
  });

  final int opSequence;
  final String title;
  final String snippet;
  final List<String> contextIds;

  @override
  bool operator ==(Object other) =>
      other is SearchHitRef &&
      other.opSequence == opSequence &&
      other.title == title &&
      other.snippet == snippet &&
      listEquals(other.contextIds, contextIds);

  @override
  int get hashCode =>
      Object.hash(opSequence, title, snippet, Object.hashAll(contextIds));
}
