import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_player/platform_player.dart';

/// The sender-side transport for the connected receiver, if any. Defaults
/// to [UnavailableMultiviewCastSenderTransport] until a real Cast Connect
/// sender exists — see
/// docs/superpowers/specs/2026-09-07-cast-multiview-remote-control-spec.md's
/// Dependencies section. Override this provider once that transport is
/// available (e.g. keyed off the existing `iptvCastProvider`'s connected
/// device), the same way `airoCastControllerProvider` is overridden per
/// platform today.
final multiviewCastSenderTransportProvider =
    Provider<MultiviewCastSenderTransport>((ref) {
      return const UnavailableMultiviewCastSenderTransport();
    });

/// The connected receiver's live MultiView grid, as last reported over
/// [multiviewCastSenderTransportProvider] — `null` for "no receiver
/// connected" rather than leaving the provider in `AsyncLoading` forever
/// when nothing is connected (a `Stream` that never emits, as
/// [UnavailableMultiviewCastSenderTransport] returns, would otherwise never
/// resolve to a value at all).
final multiviewCastReceiverStateProvider = StreamProvider<MultiviewCastState?>((
  ref,
) async* {
  yield null;
  yield* ref.watch(multiviewCastSenderTransportProvider).stateUpdates;
});
