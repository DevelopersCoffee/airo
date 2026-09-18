import 'dart:async';
import 'dart:typed_data';

/// Encodes and decodes length-prefixed binary frames for local socket transports.
///
/// Uses a 4-byte Big-Endian unsigned integer prefix to demarcate frame boundaries.
class AiroLengthPrefixedFramer {
  static const int headerSizeBytes = 4;

  final BytesBuilder _buffer = BytesBuilder(copy: false);

  /// Encodes a raw [payload] into a length-prefixed byte array.
  static Uint8List encode(Uint8List payload) {
    final header = ByteData(headerSizeBytes)..setUint32(0, payload.length, Endian.big);
    final builder = BytesBuilder(copy: false)
      ..add(header.buffer.asUint8List())
      ..add(payload);
    return builder.takeBytes();
  }

  /// Appends incoming [chunk] bytes to the internal buffer and yields any complete payloads.
  List<Uint8List> processChunk(Uint8List chunk) {
    _buffer.add(chunk);
    final results = <Uint8List>[];

    while (_buffer.length >= headerSizeBytes) {
      final bytes = _buffer.toBytes();
      final byteData = ByteData.sublistView(bytes, 0, headerSizeBytes);
      final frameLength = byteData.getUint32(0, Endian.big);

      if (_buffer.length < headerSizeBytes + frameLength) {
        break; // Wait for more data
      }

      // Extract complete frame payload
      final payload = bytes.sublist(headerSizeBytes, headerSizeBytes + frameLength);
      results.add(payload);

      // Keep remaining bytes in buffer
      final remaining = bytes.sublist(headerSizeBytes + frameLength);
      _buffer.clear();
      _buffer.add(remaining);
    }

    return results;
  }

  /// Clears the internal buffer.
  void clear() {
    _buffer.clear();
  }
}

/// Status of a local transport connection.
enum AiroTransportConnectionState {
  disconnected,
  connecting,
  connected,
  closed,
}

/// High-level plug-and-play transport engine for edge nodes over binary streams / sockets.
class AiroSocketTransportEngine {
  final StreamController<Uint8List> _incomingController =
      StreamController<Uint8List>.broadcast();
  final AiroLengthPrefixedFramer _framer = AiroLengthPrefixedFramer();

  AiroTransportConnectionState _state = AiroTransportConnectionState.disconnected;
  StreamSubscription<Uint8List>? _rawSubscription;
  Sink<List<int>>? _outgoingSink;

  AiroTransportConnectionState get state => _state;

  /// Clean Flutter-friendly stream of incoming decoded payload bytes.
  Stream<Uint8List> get incomingStream => _incomingController.stream;

  /// Binds the engine to an active raw byte stream and outgoing sink.
  void bind({
    required Stream<Uint8List> rawInputStream,
    required Sink<List<int>> outgoingSink,
  }) {
    _rawSubscription?.cancel();
    _outgoingSink = outgoingSink;
    _state = AiroTransportConnectionState.connected;

    _rawSubscription = rawInputStream.listen(
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

  /// Sends a length-prefixed payload over the active transport.
  bool send(Uint8List payload) {
    if (_state != AiroTransportConnectionState.connected || _outgoingSink == null) {
      return false;
    }
    final framed = AiroLengthPrefixedFramer.encode(payload);
    _outgoingSink!.add(framed);
    return true;
  }

  /// Mark transport as disconnected.
  void markDisconnected() {
    _state = AiroTransportConnectionState.disconnected;
    _rawSubscription?.cancel();
    _rawSubscription = null;
    _outgoingSink = null;
    _framer.clear();
  }

  /// Closes the transport engine and release resources.
  Future<void> close() async {
    _state = AiroTransportConnectionState.closed;
    await _rawSubscription?.cancel();
    _rawSubscription = null;
    _outgoingSink = null;
    _framer.clear();
    await _incomingController.close();
  }
}

/// Buffer queue that holds outgoing envelopes during network drops and automatically
/// flushes them when reconnected.
class AiroReconnectionBuffer {
  final List<Uint8List> _queue = [];
  final int maxCapacity;

  AiroReconnectionBuffer({this.maxCapacity = 100});

  /// Current number of buffered payloads.
  int get length => _queue.length;

  /// True if buffer is empty.
  bool get isEmpty => _queue.isEmpty;

  /// Enqueues a payload for later transmission.
  ///
  /// Drops oldest messages if capacity is exceeded.
  void enqueue(Uint8List payload) {
    if (_queue.length >= maxCapacity) {
      _queue.removeAt(0); // Evict oldest
    }
    _queue.add(payload);
  }

  /// Attempts to send payload directly via [engine], or enqueues it if disconnected.
  bool sendOrEnqueue(AiroSocketTransportEngine engine, Uint8List payload) {
    if (engine.state == AiroTransportConnectionState.connected) {
      final success = engine.send(payload);
      if (success) return true;
    }
    enqueue(payload);
    return false;
  }

  /// Flushes all enqueued payloads through [engine] when reconnected.
  int flush(AiroSocketTransportEngine engine) {
    if (engine.state != AiroTransportConnectionState.connected) {
      return 0;
    }

    int sentCount = 0;
    final copy = List<Uint8List>.from(_queue);
    _queue.clear();

    for (final payload in copy) {
      if (engine.send(payload)) {
        sentCount++;
      } else {
        // Re-enqueue remaining
        _queue.add(payload);
      }
    }

    return sentCount;
  }

  /// Clears all buffered messages.
  void clear() {
    _queue.clear();
  }
}
