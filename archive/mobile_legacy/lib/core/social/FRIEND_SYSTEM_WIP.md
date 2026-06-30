# Friend System & Presence - WIP

## Status: Work In Progress

This document outlines the Friend System and Presence architecture. Implementation is deferred to a future iteration.

## Overview

Local stub implementation for friend list and presence tracking. No backend required for v1.

## Data Model

```dart
class Friend {
  final String id;
  final String name;
  final String? avatar;
  final PresenceStatus status;
  final DateTime? lastSeen;
  final String? statusMessage;
}

enum PresenceStatus {
  online,
  away,
  busy,
  offline,
}

class Presence {
  final String userId;
  final PresenceStatus status;
  final DateTime timestamp;
  final String? currentActivity;
}
```

## Architecture

### Friend List Provider (Riverpod)

```dart
final friendListProvider = StateNotifierProvider<FriendListNotifier, List<Friend>>((ref) {
  return FriendListNotifier();
});

class FriendListNotifier extends StateNotifier<List<Friend>> {
  FriendListNotifier() : super([]);

  void addFriend(Friend friend) {
    state = [...state, friend];
  }

  void removeFriend(String friendId) {
    state = state.where((f) => f.id != friendId).toList();
  }

  void updateFriend(Friend friend) {
    state = state.map((f) => f.id == friend.id ? friend : f).toList();
  }
}
```

### Presence Provider (Riverpod)

```dart
final presenceProvider = StreamProvider<Map<String, Presence>>((ref) async* {
  // Local stub: emit mock presence data
  yield {
    'user1': Presence(
      userId: 'user1',
      status: PresenceStatus.online,
      timestamp: DateTime.now(),
      currentActivity: 'Playing Chess',
    ),
    'user2': Presence(
      userId: 'user2',
      status: PresenceStatus.away,
      timestamp: DateTime.now().subtract(Duration(minutes: 5)),
    ),
  };
});
```

### Local Stub Data

```dart
class LocalFriendStub {
  static final List<Friend> mockFriends = [
    Friend(
      id: 'friend1',
      name: 'Alice',
      avatar: null,
      status: PresenceStatus.online,
      lastSeen: DateTime.now(),
      statusMessage: 'Playing Chess',
    ),
    Friend(
      id: 'friend2',
      name: 'Bob',
      avatar: null,
      status: PresenceStatus.away,
      lastSeen: DateTime.now().subtract(Duration(minutes: 15)),
      statusMessage: 'In a meeting',
    ),
    Friend(
      id: 'friend3',
      name: 'Charlie',
      avatar: null,
      status: PresenceStatus.offline,
      lastSeen: DateTime.now().subtract(Duration(hours: 2)),
    ),
  ];
}
```

## UI Components

### Friend List Screen

- Display list of friends with presence status
- Show online/away/offline indicators
- Display last seen time
- Show current activity if available
- Add/remove friend buttons

### Presence Indicator

- Green dot for online
- Yellow dot for away
- Gray dot for offline
- Tooltip with status message

### Chat Integration

- Show friend list in social tab
- Quick chat access from friend list
- Presence status in chat header

## Features (v1)

- [ ] Display friend list with presence
- [ ] Add/remove friends (local only)
- [ ] Presence status indicators
- [ ] Last seen timestamps
- [ ] Current activity display
- [ ] Status message support

## Future Features (v2+)

- [ ] Backend sync
- [ ] Real-time presence updates
- [ ] Friend requests
- [ ] Blocking
- [ ] Groups
- [ ] Activity history
- [ ] Notifications

## Integration Points

### Agent Integration

- Intent: "show my friends" → open friend list
- Intent: "chat with Alice" → open chat with friend
- Tool: `social.list_friends` - Get friend list
- Tool: `social.get_presence(friend_id)` - Get friend presence
- Tool: `social.send_message(friend_id, message)` - Send message

### Music Feature

- Show friend activity: "Alice is playing music"
- Share current track with friends

### Games Feature

- Show friend activity: "Bob is playing Chess"
- Invite friends to multiplayer games

## Data Storage

### Local Storage (Hive)

```dart
class FriendBox {
  static const String boxName = 'friends';

  static Future<void> saveFriend(Friend friend) async {
    final box = Hive.box<Friend>(boxName);
    await box.put(friend.id, friend);
  }

  static Future<Friend?> getFriend(String id) async {
    final box = Hive.box<Friend>(boxName);
    return box.get(id);
  }

  static Future<List<Friend>> getAllFriends() async {
    final box = Hive.box<Friend>(boxName);
    return box.values.toList();
  }
}
```

## Privacy & Security

- Local storage only (no cloud sync in v1)
- No PII exposed in presence
- User controls what activity is shared
- Opt-in activity sharing

## QA Matrix (WIP)

- [ ] Friend list loads correctly
- [ ] Presence updates in real-time
- [ ] Add/remove friends works
- [ ] Status messages display
- [ ] Last seen timestamps accurate
- [ ] Offline friends show correctly
- [ ] Activity display works
- [ ] Chat integration works

## Dev Tasks (WIP)

- [ ] Create Friend and Presence models
- [ ] Implement FriendListNotifier
- [ ] Implement PresenceProvider
- [ ] Create LocalFriendStub
- [ ] Build FriendListScreen UI
- [ ] Build PresenceIndicator component
- [ ] Integrate with ChatScreen
- [ ] Add Hive storage
- [ ] Add Agent tool plumbing
- [ ] Add tests

## Notes

- Local stub allows testing UI without backend
- Easy to swap stub with real backend later
- Presence is mock data for now
- Activity tracking is opt-in
- No real-time sync in v1

