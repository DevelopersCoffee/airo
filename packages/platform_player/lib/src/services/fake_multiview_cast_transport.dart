import 'dart:async';

import '../models/multiview_cast_protocol.dart';
import 'multiview_cast_transport.dart';

/// An in-memory, loopback pair of [MultiviewCastReceiverTransport] and
/// [MultiviewCastSenderTransport] — a command sent on [sender] arrives on
/// [receiver], and a state published on [receiver] arrives on [sender],
/// with no real Cast session involved.
///
/// Exists so `CastMultiviewReceiverBridge` (feature_iptv) and the
/// sender-side Cast MultiView UI can each be built and tested against a
/// real transport contract before Cast Connect's native wiring exists —
/// see the spec's "Dependencies" section for why that native piece isn't
/// here yet.
class FakeMultiviewCastLink {
  FakeMultiviewCastLink()
    : _commandsToReceiver = StreamController<MultiviewCastCommand>.broadcast(),
      _statesToSender = StreamController<MultiviewCastState>.broadcast() {
    receiver = _FakeMultiviewCastReceiverTransport(
      commands: _commandsToReceiver.stream,
      onPublishState: _statesToSender.add,
    );
    sender = _FakeMultiviewCastSenderTransport(
      stateUpdates: _statesToSender.stream,
      onSendCommand: _commandsToReceiver.add,
    );
  }

  final StreamController<MultiviewCastCommand> _commandsToReceiver;
  final StreamController<MultiviewCastState> _statesToSender;

  late final MultiviewCastReceiverTransport receiver;
  late final MultiviewCastSenderTransport sender;

  Future<void> dispose() async {
    await _commandsToReceiver.close();
    await _statesToSender.close();
  }
}

class _FakeMultiviewCastReceiverTransport
    implements MultiviewCastReceiverTransport {
  _FakeMultiviewCastReceiverTransport({
    required this.commands,
    required this.onPublishState,
  });

  @override
  final Stream<MultiviewCastCommand> commands;

  final void Function(MultiviewCastState state) onPublishState;

  @override
  Future<void> publishState(MultiviewCastState state) async {
    onPublishState(state);
  }
}

class _FakeMultiviewCastSenderTransport
    implements MultiviewCastSenderTransport {
  _FakeMultiviewCastSenderTransport({
    required this.stateUpdates,
    required this.onSendCommand,
  });

  @override
  final Stream<MultiviewCastState> stateUpdates;

  final void Function(MultiviewCastCommand command) onSendCommand;

  @override
  Future<void> sendCommand(MultiviewCastCommand command) async {
    onSendCommand(command);
  }
}
