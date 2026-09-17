import 'dart:async';
import 'dart:typed_data';

import 'airo_socket_transport.dart';

/// Transport engine wrapper for WebRTC Data Channels (P2P streaming).
class AiroWebRtcDataChannelTransportEngine {
  final StreamController<Uint8List> _incomingController =
      StreamController<Uint8List>.broadcast();
  final AiroLengthPrefixedFramer _framer = AiroLengthPrefixedFramer();

  AiroTransportConnectionState _state = AiroTransportConnectionState.disconnected;
  StreamSubscription<Uint8List>? _rawSubscription;
  void Function(Uint8List payload)? _sendHandler;

  AiroTransportConnectionState get state => _state;

  /// Stream of incoming P2P payload frames.
  Stream<Uint8List> get incomingStream => _incomingController.stream;

  /// Binds the engine to a WebRTC Data Channel byte stream and send callback.
  void bind({
    required Stream<Uint8List> dataChannelStream,
    required void Function(Uint8List payload) sendHandler,
  }) {
    _rawSubscription?.cancel();
    _sendHandler = sendHandler;
    _state = AiroTransportConnectionState.connected;

    _rawSubscription = dataChannelStream.listen(
      (chunk) {
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

  /// Sends a framed message over the WebRTC Data Channel.
  bool send(Uint8List payload) {
    if (_state != AiroTransportConnectionState.connected || _sendHandler == null) {
      return false;
    }
    final framed = AiroLengthPrefixedFramer.encode(payload);
    _sendHandler!(framed);
    return true;
  }

  /// Closes the Data Channel transport.
  Future<void> close() async {
    _state = AiroTransportConnectionState.closed;
    await _rawSubscription?.cancel();
    _rawSubscription = null;
    _sendHandler = null;
    _framer.clear();
    await _incomingController.close();
  }
}
