import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/friend_models.dart';

/// Friend list provider - WIP
/// TODO: Implement real friend list fetching from backend
final friendListProvider = FutureProvider<List<Friend>>((ref) async {
  // Stub data for development
  return [
    const Friend(
      id: '1',
      name: 'Alice',
      status: PresenceStatus.online,
      statusMessage: 'Playing chess',
    ),
    const Friend(
      id: '2',
      name: 'Bob',
      status: PresenceStatus.away,
      lastSeen: null,
    ),
    const Friend(id: '3', name: 'Charlie', status: PresenceStatus.offline),
  ];
});

/// Friend requests provider - WIP
/// TODO: Implement real friend request fetching
final friendRequestsProvider = FutureProvider<List<FriendRequest>>((ref) async {
  // Stub data for development
  return [];
});

/// User presence provider - WIP
/// TODO: Implement real presence tracking
final userPresenceProvider = StreamProvider<UserPresence>((ref) async* {
  // Stub data for development
  yield UserPresence(
    userId: 'current_user',
    status: PresenceStatus.online,
    lastUpdated: DateTime.now(),
    statusMessage: 'Available',
  );
});

/// Friend controller provider
final friendControllerProvider = Provider<FriendController>((ref) {
  return FriendController(ref);
});

/// Friend controller for managing friend operations
class FriendController {
  final Ref _ref;

  FriendController(this._ref);

  /// Add friend by ID
  Future<void> addFriend(String userId) async {
    // TODO: Implement add friend logic
  }

  /// Remove friend
  Future<void> removeFriend(String friendId) async {
    // TODO: Implement remove friend logic
  }

  /// Accept friend request
  Future<void> acceptFriendRequest(String requestId) async {
    // TODO: Implement accept friend request logic
  }

  /// Reject friend request
  Future<void> rejectFriendRequest(String requestId) async {
    // TODO: Implement reject friend request logic
  }

  /// Update presence status
  Future<void> updatePresenceStatus(PresenceStatus status) async {
    // TODO: Implement update presence logic
  }

  /// Set status message
  Future<void> setStatusMessage(String message) async {
    // TODO: Implement set status message logic
  }
}
