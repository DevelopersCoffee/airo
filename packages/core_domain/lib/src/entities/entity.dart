import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Base class for all domain entities.
///
/// Entities are objects with a unique identity that persists over time.
/// Two entities are equal if their IDs are equal.
@immutable
abstract class Entity extends Equatable {
  const Entity({required this.id});

  /// Unique identifier for this entity.
  final String id;

  @override
  List<Object?> get props => [id];

  @override
  bool? get stringify => true;
}

