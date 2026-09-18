import 'dart:async';
import 'dart:typed_data';

import 'package:core_protocol/core_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroDeviceDiscoveryEngine', () {
    test('emits discovered devices over stream', () async {
      final engine = AiroFakeDiscoveryEngine();
      final discovered = <AiroDiscoveredDevice>[];
      final sub = engine.discoveredDevices.listen(discovered.add);

      await engine.startDiscovery();
      expect(engine.isScanning, isTrue);

      final device = AiroDiscoveredDevice(
        deviceId: 'edge-node-1',
        name: 'Living Room TV',
        host: '192.168.1.100',
        port: 8080,
        protocols: {AiroDiscoveryProtocol.mdns, AiroDiscoveryProtocol.ble},
        metadata: {'role': 'tvReceiver'},
      );

      engine.emitDiscovered(device);
      await pumpEventQueue();

      expect(discovered, hasLength(1));
      expect(discovered.first.deviceId, equals('edge-node-1'));
      expect(discovered.first.toDiagnosticMap(), containsPair('name', 'Living Room TV'));

      await engine.stopDiscovery();
      expect(engine.isScanning, isFalse);
      await sub.cancel();
      await engine.close();
    });
  });

  group('AiroWebSocketTransportEngine', () {
    test('frames WebSocket binary chunks and emits decoded payloads', () async {
      final engine = AiroWebSocketTransportEngine();
      final inputController = StreamController<dynamic>();
      final outputSink = _TestSink();

      engine.bind(
        rawInputStream: inputController.stream,
        outgoingSink: outputSink,
      );

      expect(engine.state, equals(AiroTransportConnectionState.connected));

      final received = <Uint8List>[];
      final sub = engine.incomingStream.listen(received.add);

      final payload = Uint8List.fromList([1, 2, 3, 4]);
      inputController.add(AiroLengthPrefixedFramer.encode(payload));
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.first, equals(payload));

      final outbound = Uint8List.fromList([10, 20]);
      expect(engine.send(outbound), isTrue);
      expect(outputSink.written, hasLength(1));

      await sub.cancel();
      await engine.close();
      await inputController.close();
    });
  });

  group('AiroWebRtcDataChannelTransportEngine', () {
    test('frames WebRTC DataChannel payloads and executes send handler', () async {
      final engine = AiroWebRtcDataChannelTransportEngine();
      final inputController = StreamController<Uint8List>();
      final sentData = <Uint8List>[];

      engine.bind(
        dataChannelStream: inputController.stream,
        sendHandler: sentData.add,
      );

      expect(engine.state, equals(AiroTransportConnectionState.connected));

      final received = <Uint8List>[];
      final sub = engine.incomingStream.listen(received.add);

      final payload = Uint8List.fromList([5, 10, 15]);
      inputController.add(AiroLengthPrefixedFramer.encode(payload));
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.first, equals(payload));

      final outbound = Uint8List.fromList([100, 200]);
      expect(engine.send(outbound), isTrue);
      expect(sentData, hasLength(1));
      expect(sentData.first, equals(AiroLengthPrefixedFramer.encode(outbound)));

      await sub.cancel();
      await engine.close();
      await inputController.close();
    });
  });

  group('AiroZeroConfigHandshakeEngine', () {
    test('generates keypair, performs zero-config handshake, and derives session key', () {
      final localKeys = AiroZeroConfigHandshakeEngine.generateEphemeralKeyPair('local-seed');
      final peerKeys = AiroZeroConfigHandshakeEngine.generateEphemeralKeyPair('peer-seed');

      final engine = AiroZeroConfigHandshakeEngine();
      final result = engine.performHandshake(
        peerNodeId: 'node-b',
        localPrivateKey: localKeys['privateKey']!,
        peerPublicKey: peerKeys['publicKey']!,
        proofPresent: true,
        isPeerTrusted: true,
      );

      expect(result.accepted, isTrue);
      expect(result.peerNodeId, equals('node-b'));
      expect(result.sharedSessionKey, isNotNull);
      expect(result.sharedSessionKey!.length, equals(32));
    });

    test('rejects handshake when proof is missing or peer is untrusted', () {
      final localKeys = AiroZeroConfigHandshakeEngine.generateEphemeralKeyPair('local-seed');
      final peerKeys = AiroZeroConfigHandshakeEngine.generateEphemeralKeyPair('peer-seed');

      final engine = AiroZeroConfigHandshakeEngine();

      final missingProof = engine.performHandshake(
        peerNodeId: 'node-b',
        localPrivateKey: localKeys['privateKey']!,
        peerPublicKey: peerKeys['publicKey']!,
        proofPresent: false,
        isPeerTrusted: true,
      );

      final untrusted = engine.performHandshake(
        peerNodeId: 'node-b',
        localPrivateKey: localKeys['privateKey']!,
        peerPublicKey: peerKeys['publicKey']!,
        proofPresent: true,
        isPeerTrusted: false,
      );

      expect(missingProof.accepted, isFalse);
      expect(missingProof.codes, contains('MISSING_AUTH_PROOF'));
      expect(untrusted.accepted, isFalse);
      expect(untrusted.codes, contains('UNTRUSTED_PEER'));
    });
  });

  group('AiroPayloadCipher (E2EE)', () {
    test('encrypts and decrypts payload correctly with nonces', () {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final plainText = Uint8List.fromList([72, 101, 108, 108, 111, 32, 65, 105, 114, 111]); // "Hello Airo"

      final encrypted = AiroPayloadCipher.encrypt(
        plainText: plainText,
        sharedKey: key,
      );

      final decrypted = AiroPayloadCipher.decrypt(
        encrypted: encrypted,
        sharedKey: key,
      );

      expect(decrypted, equals(plainText));

      // Test byte serialization roundtrip
      final bytes = encrypted.toBytes();
      final deserialized = AiroEncryptedPayload.fromBytes(bytes);
      final decryptedFromBytes = AiroPayloadCipher.decrypt(
        encrypted: deserialized,
        sharedKey: key,
      );

      expect(decryptedFromBytes, equals(plainText));
    });

    test('throws StateError when payload is tampered', () {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final plainText = Uint8List.fromList([1, 2, 3, 4, 5]);

      final encrypted = AiroPayloadCipher.encrypt(
        plainText: plainText,
        sharedKey: key,
      );

      // Tamper tag
      final tamperedTag = Uint8List.fromList(encrypted.tag);
      tamperedTag[0] ^= 0xFF;

      final tampered = AiroEncryptedPayload(
        nonce: encrypted.nonce,
        ciphertext: encrypted.ciphertext,
        tag: tamperedTag,
      );

      expect(
        () => AiroPayloadCipher.decrypt(encrypted: tampered, sharedKey: key),
        throwsStateError,
      );
    });
  });
}

class _TestSink implements Sink<dynamic> {
  final List<dynamic> written = [];

  @override
  void add(dynamic data) {
    written.add(data);
  }

  @override
  void close() {}
}
