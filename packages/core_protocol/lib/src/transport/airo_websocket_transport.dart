import 'dart:async';
import 'dart:typed_data';

import 'airo_socket_transport.dart';

/// Transport engine for WebSocket connections (Web, Mobile, Desktop).
class AiroWebSocketTransportEngine {
  final StreamController<Uint8List> _incomingController =
      StreamController<Uint8List>.broadcast();
  final AiroLengthPrefixedFramer _framer = AiroLengthPrefixedFramer();

  AiroTransportConnectionState _state = AiroTransportConnectionState.disconnected;
  StreamSubscription<dynamic>? _rawSubscription;
  Sink<dynamic>? _outgoingSink;

  AiroTransportConnectionState get state => _state;

  /// Clean stream of incoming binary envelope payloads.
  Stream<Uint8List> get incomingStream => _incomingController.stream;

  /// Binds the transport to an active WebSocket input stream and outgoing sink.
  void bind({
    required Stream<dynamic> rawInputStream,
    required Sink<dynamic> outgoingSink,
  }) {
    _rawSubscription?.cancel();
    _outgoingSink = outgoingSink;
    _state = AiroTransportConnectionState.connected;

    _rawSubscription = rawInputStream.listen(
      (data) {
        Uint8List chunk;
        if (data is Uint8List) {
          chunk = data;
        } else if (data is List<int>) {
          chunk = Uint8List.fromList(data);
        } else {
          return; // Ignore non-binary frame
        }

        final frames = _framer.processChunk(chunk);
        for (final frame in frames) {
          _incomingController.add(frame);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _incomingController.addError(error, stackTrace);
      },
      onDone: () {
        _state = AiroTransportConnectionState.disconnected;
      },
    );
  }

  /// Sends a framed payload over the WebSocket connection.
  bool send(Uint8List payload) {
    if (_state != AiroTransportConnectionState.connected || _outgoingSink == null) {
      return false;
    }
    final framed = AiroLengthPrefixedFramer.encode(payload);
    _outgoingSink!.add(framed);
    return true;
  }

  /// Closes the transport.
  Future<void> close() async {
    _state = AiroTransportConnectionState.closed;
    await _rawSubscription?.cancel();
    _rawSubscription = null;
    _outgoingSink = null;
    _framer.clear();
    await _incomingController.close();
  }
}
