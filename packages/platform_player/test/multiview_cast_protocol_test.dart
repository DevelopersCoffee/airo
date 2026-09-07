import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  group('MultiviewCastCommand round-trip', () {
    test('set_slot', () {
      const command = MultiviewSetSlotCommand(
        slotId: 'b',
        channelId: 'yrf-music',
      );
      final decoded = MultiviewCastCommand.fromJson(command.toJson());
      expect(decoded, command);
    });

    test('remove_slot', () {
      const command = MultiviewRemoveSlotCommand(slotId: 'b');
      final decoded = MultiviewCastCommand.fromJson(command.toJson());
      expect(decoded, command);
    });

    test('promote', () {
      const command = MultiviewPromoteCommand(slotId: 'a');
      final decoded = MultiviewCastCommand.fromJson(command.toJson());
      expect(decoded, command);
    });

    test('swap', () {
      const command = MultiviewSwapCommand(firstSlotId: 'a', secondSlotId: 'b');
      final decoded = MultiviewCastCommand.fromJson(command.toJson());
      expect(decoded, command);
    });

    test('query_state', () {
      const command = MultiviewQueryStateCommand();
      final decoded = MultiviewCastCommand.fromJson(command.toJson());
      expect(decoded, command);
    });

    test('an unknown type throws rather than silently no-op-ing', () {
      expect(
        () => MultiviewCastCommand.fromJson({'type': 'multiview.teleport'}),
        throwsA(isA<MultiviewCastProtocolException>()),
      );
    });

    test('a missing type field throws', () {
      expect(
        () => MultiviewCastCommand.fromJson({'slotId': 'a'}),
        throwsA(isA<MultiviewCastProtocolException>()),
      );
    });

    test('a command missing a required field throws', () {
      expect(
        () => MultiviewCastCommand.fromJson({'type': 'multiview.set_slot'}),
        throwsA(isA<MultiviewCastProtocolException>()),
      );
    });
  });

  group('MultiviewCastState round-trip', () {
    test('encodes and decodes every slot field', () {
      const state = MultiviewCastState(
        capacity: 2,
        slots: [
          MultiviewCastSlot(
            slotId: 'a',
            channelId: 'aajtak-hd',
            channelName: 'Aaj Tak HD',
            featured: true,
          ),
          MultiviewCastSlot(
            slotId: 'b',
            channelId: 'yrf-music',
            channelName: 'YRF Music',
            featured: false,
          ),
        ],
      );

      final decoded = MultiviewCastState.fromJson(state.toJson());
      expect(decoded, state);
    });

    test('an empty grid round-trips too', () {
      const state = MultiviewCastState(capacity: 4, slots: []);
      expect(MultiviewCastState.fromJson(state.toJson()), state);
    });

    test('a missing capacity field throws', () {
      expect(
        () => MultiviewCastState.fromJson({'slots': []}),
        throwsA(isA<MultiviewCastProtocolException>()),
      );
    });

    test('a missing slots field throws', () {
      expect(
        () => MultiviewCastState.fromJson({'capacity': 2}),
        throwsA(isA<MultiviewCastProtocolException>()),
      );
    });
  });
}
