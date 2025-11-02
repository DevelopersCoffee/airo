import 'package:equatable/equatable.dart';

/// User presence status
enum PresenceStatus {
  online,
  away,
  busy,
  offline,
}

/// Friend model
class Friend extends Equatable {
  final String id;
  final String name;
  final String? avatarUrl;
  final PresenceStatus status;
  final DateTime? lastSeen;
  final String? statusMessage;

  const Friend({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.status,
    this.lastSeen,
    this.statusMessage,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    avatarUrl,
    status,
    lastSeen,
    statusMessage,
  ];
}

/// Friend request model
class FriendRequest extends Equatable {
  final String id;
  final String fromUserId;
  final String toUserId;
  final DateTime createdAt;
  final bool accepted;

  const FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.createdAt,
    required this.accepted,
  });

  @override
  List<Object?> get props => [id, fromUserId, toUserId, createdAt, accepted];
}

/// User presence model
class UserPresence extends Equatable {
  final String userId;
  final PresenceStatus status;
  final DateTime lastUpdated;
  final String? statusMessage;
  final String? currentActivity;

  const UserPresence({
    required this.userId,
    required this.status,
    required this.lastUpdated,
    this.statusMessage,
    this.currentActivity,
  });

  @override
  List<Object?> get props => [
    userId,
    status,
    lastUpdated,
    statusMessage,
    currentActivity,
  ];
}

