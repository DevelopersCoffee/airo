import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  test('a command sent on sender arrives on receiver', () async {
    final link = FakeMultiviewCastLink();
    addTearDown(link.dispose);

    const command = MultiviewSetSlotCommand(slotId: 'a', channelId: 'yrf');
    final received = link.receiver.commands.first;
    await link.sender.sendCommand(command);

    expect(await received, command);
  });

  test('a state published on receiver arrives on sender', () async {
    final link = FakeMultiviewCastLink();
    addTearDown(link.dispose);

    const state = MultiviewCastState(capacity: 2, slots: []);
    final received = link.sender.stateUpdates.first;
    await link.receiver.publishState(state);

    expect(await received, state);
  });
}
