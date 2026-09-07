import 'package:equatable/equatable.dart';

/// Custom Cast message namespace for remote MultiView control (see
/// docs/superpowers/specs/2026-09-07-cast-multiview-remote-control-spec.md).
/// Google's `urn:x-cast:<reverse-domain>` convention.
const String multiviewCastNamespace =
    'urn:x-cast:com.developerscoffee.airo.multiview';

/// Bumped whenever a message shape changes incompatibly. A receiver or
/// sender on an older version should ignore messages it doesn't recognize
/// rather than crash — see [MultiviewCastCommand.fromJson] and
/// [MultiviewCastState.fromJson]'s unknown-type handling.
const int multiviewCastProtocolVersion = 1;

/// Thrown when a message can't be decoded — a version mismatch, a
/// corrupted payload, or a genuinely unknown command type.
class MultiviewCastProtocolException implements Exception {
  const MultiviewCastProtocolException(this.message);

  final String message;

  @override
  String toString() => 'MultiviewCastProtocolException: $message';
}

/// Sender -> receiver. Addressed by `slotId` (a grid position), not channel
/// id, so a sender can reference "the tile at position B" before knowing
/// what's in it yet — see the spec's protocol-shape section for why.
sealed class MultiviewCastCommand extends Equatable {
  const MultiviewCastCommand();

  Map<String, dynamic> toJson();

  static MultiviewCastCommand fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    if (type is! String) {
      throw const MultiviewCastProtocolException(
        'Missing or non-string "type" field.',
      );
    }
    switch (type) {
      case 'multiview.set_slot':
        return MultiviewSetSlotCommand(
          slotId: _requireString(json, 'slotId'),
          channelId: _requireString(json, 'channelId'),
        );
      case 'multiview.remove_slot':
        return MultiviewRemoveSlotCommand(
          slotId: _requireString(json, 'slotId'),
        );
      case 'multiview.promote':
        return MultiviewPromoteCommand(slotId: _requireString(json, 'slotId'));
      case 'multiview.swap':
        return MultiviewSwapCommand(
          firstSlotId: _requireString(json, 'firstSlotId'),
          secondSlotId: _requireString(json, 'secondSlotId'),
        );
      case 'multiview.query_state':
        return const MultiviewQueryStateCommand();
      default:
        throw MultiviewCastProtocolException('Unknown command type "$type".');
    }
  }
}

class MultiviewSetSlotCommand extends MultiviewCastCommand {
  const MultiviewSetSlotCommand({
    required this.slotId,
    required this.channelId,
  });

  final String slotId;
  final String channelId;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'multiview.set_slot',
    'slotId': slotId,
    'channelId': channelId,
  };

  @override
  List<Object?> get props => [slotId, channelId];
}

class MultiviewRemoveSlotCommand extends MultiviewCastCommand {
  const MultiviewRemoveSlotCommand({required this.slotId});

  final String slotId;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'multiview.remove_slot',
    'slotId': slotId,
  };

  @override
  List<Object?> get props => [slotId];
}

class MultiviewPromoteCommand extends MultiviewCastCommand {
  const MultiviewPromoteCommand({required this.slotId});

  final String slotId;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'multiview.promote',
    'slotId': slotId,
  };

  @override
  List<Object?> get props => [slotId];
}

class MultiviewSwapCommand extends MultiviewCastCommand {
  const MultiviewSwapCommand({
    required this.firstSlotId,
    required this.secondSlotId,
  });

  final String firstSlotId;
  final String secondSlotId;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'multiview.swap',
    'firstSlotId': firstSlotId,
    'secondSlotId': secondSlotId,
  };

  @override
  List<Object?> get props => [firstSlotId, secondSlotId];
}

/// Asks the receiver to publish its current [MultiviewCastState] immediately
/// — used right after a sender connects, before any command of its own.
class MultiviewQueryStateCommand extends MultiviewCastCommand {
  const MultiviewQueryStateCommand();

  @override
  Map<String, dynamic> toJson() => {'type': 'multiview.query_state'};

  @override
  List<Object?> get props => [];
}

/// One occupied grid position, as reported by the receiver.
class MultiviewCastSlot extends Equatable {
  const MultiviewCastSlot({
    required this.slotId,
    required this.channelId,
    required this.channelName,
    required this.featured,
  });

  final String slotId;
  final String channelId;
  final String channelName;
  final bool featured;

  factory MultiviewCastSlot.fromJson(Map<String, dynamic> json) {
    return MultiviewCastSlot(
      slotId: _requireString(json, 'slotId'),
      channelId: _requireString(json, 'channelId'),
      channelName: _requireString(json, 'channelName'),
      featured: json['featured'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'slotId': slotId,
    'channelId': channelId,
    'channelName': channelName,
    'featured': featured,
  };

  @override
  List<Object?> get props => [slotId, channelId, channelName, featured];
}

/// Receiver -> sender. The receiver's actual MultiView state, pushed after
/// every change (including one a sender's own command caused) so the
/// sender's UI reflects reality — a rejection (e.g. capacity reached)
/// shows up here as "the slot didn't change" rather than a separate error
/// message the sender has to correlate back to its own command.
class MultiviewCastState extends Equatable {
  const MultiviewCastState({required this.capacity, required this.slots});

  final int capacity;
  final List<MultiviewCastSlot> slots;

  factory MultiviewCastState.fromJson(Map<String, dynamic> json) {
    final capacity = json['capacity'];
    if (capacity is! int) {
      throw const MultiviewCastProtocolException(
        'Missing or non-int "capacity" field.',
      );
    }
    final rawSlots = json['slots'];
    if (rawSlots is! List) {
      throw const MultiviewCastProtocolException('Missing "slots" list.');
    }
    return MultiviewCastState(
      capacity: capacity,
      slots: [
        for (final rawSlot in rawSlots)
          MultiviewCastSlot.fromJson(rawSlot as Map<String, dynamic>),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'type': 'multiview.state',
    'capacity': capacity,
    'slots': [for (final slot in slots) slot.toJson()],
  };

  @override
  List<Object?> get props => [capacity, slots];
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw MultiviewCastProtocolException('Missing or non-string "$key" field.');
  }
  return value;
}
