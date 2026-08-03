import '../models/projection_models.dart';

/// Graph, timeline and search — three views of one log.
///
/// Projections are disposable. Deleting an index must genuinely rebuild it,
/// which is why [rebuild] reports real progress rather than resolving
/// instantly.
abstract interface class ProjectionPort {
  Future<ProjectionState> stateOf(ProjectionKind kind);

  /// All three at once. They can be in three different states and the
  /// inspector shows each independently.
  Future<List<ProjectionState>> states();

  Stream<ProjectionState> rebuild(ProjectionKind kind);

  /// Ranked locally by embedding plus keyword.
  Future<List<SearchHitRef>> search(String query, {String? contextId});
}
