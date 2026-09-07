import 'dart:async';

import 'package:flutter/services.dart';

/// One message on an app-defined Cast namespace, as delivered by
/// [GoogleCastCustomMessageChannel.messages].
class CastCustomMessage {
  /// Creates a message record for [namespace] carrying [message].
  const CastCustomMessage({required this.namespace, required this.message});

  /// The `urn:x-cast:...` namespace this message arrived on.
  final String namespace;

  /// The raw message payload, exactly as sent by the other side.
  final String message;
}

/// Sends and receives messages on an app-defined Cast namespace — the
/// `CastSession.sendMessage` / `setMessageReceivedCallbacks` pair the native
/// Cast SDK exposes alongside its built-in media namespace.
///
/// Android only today; iOS has no native implementation yet. A receiver
/// (Cast Connect app or custom web receiver) that hasn't registered the same
/// namespace never sees anything sent here — the stock default media
/// receiver in particular ignores it entirely.
class GoogleCastCustomMessageChannel {
  GoogleCastCustomMessageChannel._();

  /// The process-wide instance — the underlying native channel is itself a
  /// singleton (one Cast session per app), so this mirrors that.
  static final GoogleCastCustomMessageChannel instance =
      GoogleCastCustomMessageChannel._();

  static const MethodChannel _channel = MethodChannel(
    'com.felnanuke.google_cast.custom_message',
  );

  final StreamController<CastCustomMessage> _messages =
      StreamController<CastCustomMessage>.broadcast();
  bool _handlerAttached = false;

  /// Messages arriving on whichever namespace was last passed to [listen].
  Stream<CastCustomMessage> get messages => _messages.stream;

  /// Starts listening for messages on [namespace]. Safe to call again with a
  /// different namespace — the native side replaces its registration rather
  /// than stacking listeners.
  ///
  /// Throws [MissingPluginException] on a platform with no native
  /// implementation (iOS, as of writing — only Android is wired).
  Future<void> listen(String namespace) async {
    if (!_handlerAttached) {
      _channel.setMethodCallHandler(_handleMethodCall);
      _handlerAttached = true;
    }
    await _channel.invokeMethod<void>('setNamespace', namespace);
  }

  /// Sends [message] on [namespace] to the currently connected Cast session.
  /// Throws a [PlatformException] with code `NO_SESSION` if nothing is
  /// connected, `SEND_FAILED` if the SDK call itself fails, or
  /// [MissingPluginException] on a platform with no native implementation.
  Future<void> sendMessage(String namespace, String message) async {
    await _channel.invokeMethod<void>('sendMessage', {
      'namespace': namespace,
      'message': message,
    });
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onMessageReceived') return;
    final args = Map<String, dynamic>.from(call.arguments as Map);
    _messages.add(
      CastCustomMessage(
        namespace: args['namespace'] as String,
        message: args['message'] as String,
      ),
    );
  }
}
