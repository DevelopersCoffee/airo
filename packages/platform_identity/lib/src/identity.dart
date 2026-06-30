
abstract class EntityId {
  final String value;
  const EntityId(this.value);
  @override
  bool operator ==(Object other) => identical(this, other) || other is EntityId && runtimeType == other.runtimeType && value == other.value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}

class ArtifactId extends EntityId { const ArtifactId(super.value); }
class StageId extends EntityId { const StageId(super.value); }
class ProviderId extends EntityId { const ProviderId(super.value); }
class PipelineId extends EntityId { const PipelineId(super.value); }
class BackendId extends EntityId { const BackendId(super.value); }
class SessionId extends EntityId { const SessionId(super.value); }
class DocumentId extends EntityId { const DocumentId(super.value); }
