import 'dart:async';
import 'dart:typed_data';

import 'package:core_protocol/core_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroLengthPrefixedFramer', () {
    test('encodes payload with 4-byte big-endian header', () {
      final payload = Uint8List.fromList([1, 2, 3, 4, 5]);
      final framed = AiroLengthPrefixedFramer.encode(payload);

      expect(framed.length, equals(9));
      expect(framed[0], equals(0));
      expect(framed[1], equals(0));
      expect(framed[2], equals(0));
      expect(framed[3], equals(5)); // Length = 5
      expect(framed.sublist(4), equals(payload));
    });

    test('decodes single and split chunks correctly', () {
      final framer = AiroLengthPrefixedFramer();
      final p1 = Uint8List.fromList([10, 20]);
      final p2 = Uint8List.fromList([30, 40, 50]);

      final bytes1 = AiroLengthPrefixedFramer.encode(p1);
      final bytes2 = AiroLengthPrefixedFramer.encode(p2);

      // Pass first packet as single chunk
      final res1 = framer.processChunk(bytes1);
      expect(res1, hasLength(1));
      expect(res1.first, equals(p1));

      // Pass second packet split across two chunks
      final splitIndex = 3;
      final partA = bytes2.sublist(0, splitIndex);
      final partB = bytes2.sublist(splitIndex);

      final resPartA = framer.processChunk(partA);
      expect(resPartA, isEmpty);

      final resPartB = framer.processChunk(partB);
      expect(resPartB, hasLength(1));
      expect(resPartB.first, equals(p2));
    });
  });

  group('AiroSocketTransportEngine', () {
    test('binds streams, receives incoming framed messages, and sends outbound', () async {
      final engine = AiroSocketTransportEngine();
      final inputController = StreamController<Uint8List>();
      final outputSink = _TestSink();

      engine.bind(
        rawInputStream: inputController.stream,
        outgoingSink: outputSink,
      );

      expect(engine.state, equals(AiroTransportConnectionState.connected));

      final received = <Uint8List>[];
      final sub = engine.incomingStream.listen(received.add);

      // Send payload to inputController
      final testMessage = Uint8List.fromList([100, 101, 102]);
      inputController.add(AiroLengthPrefixedFramer.encode(testMessage));

      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.first, equals(testMessage));

      // Send outbound payload
      final outboundPayload = Uint8List.fromList([200, 201]);
      final sent = engine.send(outboundPayload);

      expect(sent, isTrue);
      expect(outputSink.writtenBytes, isNotEmpty);
      expect(
        outputSink.writtenBytes.first,
        equals(AiroLengthPrefixedFramer.encode(outboundPayload)),
      );

      await sub.cancel();
      await engine.close();
      await inputController.close();
      expect(engine.state, equals(AiroTransportConnectionState.closed));
    });
  });

  group('AiroReconnectionBuffer', () {
    test('enqueues when disconnected and flushes when reconnected', () {
      final engine = AiroSocketTransportEngine();
      final buffer = AiroReconnectionBuffer(maxCapacity: 5);

      final p1 = Uint8List.fromList([1]);
      final p2 = Uint8List.fromList([2]);

      // Attempt send while disconnected -> should enqueue
      final sent1 = buffer.sendOrEnqueue(engine, p1);
      final sent2 = buffer.sendOrEnqueue(engine, p2);

      expect(sent1, isFalse);
      expect(sent2, isFalse);
      expect(buffer.length, equals(2));

      // Bind engine to connect
      final inputController = StreamController<Uint8List>();
      final outputSink = _TestSink();
      engine.bind(
        rawInputStream: inputController.stream,
        outgoingSink: outputSink,
      );

      // Flush buffer
      final flushedCount = buffer.flush(engine);
      expect(flushedCount, equals(2));
      expect(buffer.isEmpty, isTrue);
      expect(outputSink.writtenBytes, hasLength(2));

      engine.close();
      inputController.close();
    });

    test('evicts oldest messages when capacity limit is reached', () {
      final buffer = AiroReconnectionBuffer(maxCapacity: 2);
      buffer.enqueue(Uint8List.fromList([1]));
      buffer.enqueue(Uint8List.fromList([2]));
      buffer.enqueue(Uint8List.fromList([3])); // Evicts [1]

      expect(buffer.length, equals(2));
    });
  });
}

class _TestSink implements Sink<List<int>> {
  final List<Uint8List> writtenBytes = [];

  @override
  void add(List<int> data) {
    writtenBytes.add(Uint8List.fromList(data));
  }

  @override
  void close() {}
}
