import 'dart:async';
import 'dart:convert';

import 'package:flutter_chrome_cast/custom_message.dart';

import '../models/multiview_cast_protocol.dart';
import 'multiview_cast_transport.dart';

/// Real sender transport, wired to [GoogleCastCustomMessageChannel] — see
/// docs/superpowers/specs/2026-09-07-cast-multiview-remote-control-spec.md.
///
/// This only carries bytes between the two ends; whether anything is
/// actually listening on [multiviewCastNamespace] depends entirely on the
/// connected receiver. As of writing no receiver registers that namespace
/// (there is no Cast Connect app yet — see the spec's Dependencies), so
/// [sendCommand] reaches a live Cast session but nothing acts on it, and
/// [stateUpdates] never emits. Swap this in ahead of that receiver existing
/// so the sender side is ready once it does.
class GoogleCastMultiviewSenderTransport
    implements MultiviewCastSenderTransport {
  GoogleCastMultiviewSenderTransport({GoogleCastCustomMessageChannel? channel})
    : _channel = channel ?? GoogleCastCustomMessageChannel.instance {
    unawaited(_channel.listen(multiviewCastNamespace));
  }

  final GoogleCastCustomMessageChannel _channel;

  @override
  Future<void> sendCommand(MultiviewCastCommand command) {
    return _channel.sendMessage(
      multiviewCastNamespace,
      jsonEncode(command.toJson()),
    );
  }

  @override
  Stream<MultiviewCastState> get stateUpdates => _channel.messages
      .where((message) => message.namespace == multiviewCastNamespace)
      .expand(_decodeState);

  // A malformed or foreign-shaped frame is dropped rather than crashing the
  // stream — see MultiviewCastCommand.fromJson's doc comment on the same
  // "ignore what you don't recognize" contract.
  static Iterable<MultiviewCastState> _decodeState(CastCustomMessage raw) {
    try {
      final json = jsonDecode(raw.message);
      if (json is! Map<String, dynamic> || json['type'] != 'multiview.state') {
        return const [];
      }
      return [MultiviewCastState.fromJson(json)];
    } on Object {
      return const [];
    }
  }
}
