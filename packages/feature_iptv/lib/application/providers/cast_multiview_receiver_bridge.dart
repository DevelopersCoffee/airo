import 'dart:async';

import 'package:collection/collection.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';

import 'multiview_provider.dart';

/// Drives a receiver-side [MultiviewController] from commands arriving over
/// a [MultiviewCastReceiverTransport] — see
/// docs/superpowers/specs/2026-09-07-cast-multiview-remote-control-spec.md.
///
/// Deliberately calls the exact same [MultiviewController] methods the
/// local TV UI already calls (`toggle`/`promote`/`swap` — see
/// `AiroTvShell._toggleMultiview`) so there is no parallel
/// receiver-only multiview implementation to keep in sync.
///
/// `slotId` in incoming commands is treated as the occupied session's
/// channel id, not an independent identity: [MultiviewController] has no
/// concept of an empty slot or a slot whose id differs from its channel's
/// id, so `MultiviewSetSlotCommand`'s `channelId` is what actually gets
/// added (`slotId` is only meaningful sender-side, before a channel is
/// assigned to a position — see the spec's protocol-shape note).
class CastMultiviewReceiverBridge {
  CastMultiviewReceiverBridge({
    required MultiviewCastReceiverTransport transport,
    required MultiviewController controller,
    required IPTVChannel? Function(String channelId) resolveChannel,
  }) : // Public constructor labels kept independent of the private fields
       // so callers outside this library can pass them by name.
       // ignore: prefer_initializing_formals
       _transport = transport,
       // ignore: prefer_initializing_formals
       _controller = controller,
       // ignore: prefer_initializing_formals
       _resolveChannel = resolveChannel;

  final MultiviewCastReceiverTransport _transport;
  final MultiviewController _controller;
  final IPTVChannel? Function(String channelId) _resolveChannel;

  StreamSubscription<MultiviewCastCommand>? _commandSubscription;
  StreamSubscription<MultiviewState>? _stateSubscription;

  /// Starts listening for commands and publishing state changes. Publishes
  /// once immediately so a sender that just connected doesn't have to wait
  /// for the next state change to see what's already on screen.
  void start() {
    _stateSubscription = _controller.stream.listen(_publish);
    _commandSubscription = _transport.commands.listen(_handle);
    _publish(_controller.currentState);
  }

  Future<void> dispose() async {
    await _commandSubscription?.cancel();
    await _stateSubscription?.cancel();
  }

  Future<void> _handle(MultiviewCastCommand command) async {
    switch (command) {
      case MultiviewSetSlotCommand(:final channelId):
        final channel = _resolveChannel(channelId);
        // An unknown channel id (stale sender-side catalog, a channel the
        // receiver's playlist doesn't have) is silently ignored rather than
        // throwing — the next state publish tells the sender it didn't
        // take, the same "rejection shows up as no change" contract the
        // spec calls for.
        if (channel == null) return;
        await _controller.toggle(channel);
      case MultiviewRemoveSlotCommand(:final slotId):
        final session = _controller.currentState.sessions.firstWhereOrNull(
          (session) => session.id == slotId,
        );
        if (session == null) return;
        await _controller.toggle(session.channel);
      case MultiviewPromoteCommand(:final slotId):
        await _controller.promote(slotId);
      case MultiviewSwapCommand(:final firstSlotId, :final secondSlotId):
        _controller.swap(firstSlotId, secondSlotId);
      case MultiviewQueryStateCommand():
        _publish(_controller.currentState);
      case MultiviewSetLayoutCommand(:final layout):
        _controller.setLayout(layout);
    }
  }

  void _publish(MultiviewState state) {
    unawaited(
      _transport.publishState(
        MultiviewCastState(
          capacity: state.capacity,
          layout: state.layout,
          slots: [
            for (final session in state.sessions)
              MultiviewCastSlot(
                slotId: session.id,
                channelId: session.id,
                channelName: session.channel.name,
                featured: session.id == state.featuredChannelId,
              ),
          ],
        ),
      ),
    );
  }
}
