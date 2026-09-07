import '../models/multiview_cast_protocol.dart';
import 'multiview_cast_transport.dart';

/// Default [MultiviewCastSenderTransport] until a real Cast Connect
/// implementation exists (see the Cast MultiView remote-control spec's
/// Dependencies section) — sends are silently dropped and no state ever
/// arrives, the same "unavailable" shape as [UnavailableAiroCastController]
/// for the existing single-channel cast path.
class UnavailableMultiviewCastSenderTransport
    implements MultiviewCastSenderTransport {
  const UnavailableMultiviewCastSenderTransport();

  @override
  Future<void> sendCommand(MultiviewCastCommand command) async {}

  @override
  Stream<MultiviewCastState> get stateUpdates => const Stream.empty();
}

/// Default [MultiviewCastReceiverTransport] on every platform that isn't
/// Airo TV's own Cast Connect receiver — see
/// [AiroCastReceiverMultiviewTransport] and the Cast MultiView
/// remote-control spec's Dependencies section. Nothing ever arrives and
/// published state is silently dropped, the same shape as
/// [UnavailableMultiviewCastSenderTransport] on the sender side.
class UnavailableMultiviewCastReceiverTransport
    implements MultiviewCastReceiverTransport {
  const UnavailableMultiviewCastReceiverTransport();

  @override
  Stream<MultiviewCastCommand> get commands => const Stream.empty();

  @override
  Future<void> publishState(MultiviewCastState state) async {}
}
