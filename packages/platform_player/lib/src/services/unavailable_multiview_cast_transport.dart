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
