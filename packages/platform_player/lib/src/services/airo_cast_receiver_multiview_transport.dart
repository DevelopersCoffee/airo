import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/multiview_cast_protocol.dart';
import 'multiview_cast_transport.dart';

/// Real receiver transport, wired to the TV app's own native Cast Connect
/// bridge (`AiroCastReceiverMultiviewPlugin`, Kotlin) — see
/// docs/superpowers/specs/2026-09-07-cast-multiview-remote-control-spec.md.
///
/// Unlike the sender side (which rides the shared `flutter_chrome_cast`
/// plugin), this channel is Airo TV's own native code: Cast Connect's
/// `CastReceiverContext` only exists in a Cast Connect receiver app, so
/// there's no reusable third-party plugin for it. Dev/test only — the
/// receiver app (F353F9C7) is unpublished, reachable only from a
/// registered test device.
class AiroCastReceiverMultiviewTransport implements MultiviewCastReceiverTransport {
  AiroCastReceiverMultiviewTransport({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('com.developerscoffee.airo/cast_multiview_receiver') {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final MethodChannel _channel;
  final StreamController<MultiviewCastCommand> _commands =
      StreamController<MultiviewCastCommand>.broadcast();

  @override
  Stream<MultiviewCastCommand> get commands => _commands.stream;

  @override
  Future<void> publishState(MultiviewCastState state) async {
    await _channel.invokeMethod<void>('publishState', {
      'message': jsonEncode(state.toJson()),
    });
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onCommand') return;
    final args = Map<String, dynamic>.from(call.arguments as Map);
    final message = args['message'] as String;
    // A malformed or unrecognized command is dropped rather than crashing
    // the stream — same "ignore what you don't recognize" contract as
    // MultiviewCastCommand.fromJson's own doc comment.
    try {
      final json = jsonDecode(message);
      if (json is! Map<String, dynamic>) return;
      _commands.add(MultiviewCastCommand.fromJson(json));
    } on Object {
      return;
    }
  }
}
