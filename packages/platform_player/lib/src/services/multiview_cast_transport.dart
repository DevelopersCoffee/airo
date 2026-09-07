import '../models/multiview_cast_protocol.dart';

/// Receiver side of the MultiView Cast channel (see
/// docs/superpowers/specs/2026-09-07-cast-multiview-remote-control-spec.md).
/// A real implementation wraps a Cast Connect `CastReceiverContext` custom
/// message channel bound to [multiviewCastNamespace] — this interface exists
/// so the command-handling logic (`CastMultiviewReceiverBridge` in
/// feature_iptv) is testable without one.
abstract interface class MultiviewCastReceiverTransport {
  /// Commands arriving from whichever sender is currently connected. A
  /// implementation is only expected to have at most one connected sender
  /// at a time (see the spec's "one sender per receiver session" scope
  /// note) — multi-sender fan-in is not this interface's concern.
  Stream<MultiviewCastCommand> get commands;

  /// Pushes the receiver's current grid state to the connected sender.
  /// Called after every [commands] event this receiver acted on
  /// (including a rejection, where the state simply doesn't change) and
  /// once eagerly on connect, so a sender never has to guess whether its
  /// command took effect.
  Future<void> publishState(MultiviewCastState state);
}

/// Sender side of the MultiView Cast channel. A real implementation only
/// makes sense while the underlying [AiroCastController] session is
/// connected — this interface doesn't model connection lifecycle itself
/// (the existing cast session already does).
abstract interface class MultiviewCastSenderTransport {
  /// Sends one command to the connected receiver.
  Future<void> sendCommand(MultiviewCastCommand command);

  /// State pushes from the receiver — see
  /// [MultiviewCastReceiverTransport.publishState].
  Stream<MultiviewCastState> get stateUpdates;
}
