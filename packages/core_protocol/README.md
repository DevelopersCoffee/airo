# Core Protocol (`airo_protocol`)

[![pub package](https://img.shields.io/pub/v/airo_protocol.svg)](https://pub.dev/packages/airo_protocol)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Shared connected-node protocol contracts and plug-and-play local edge transport primitives for Airo V2 and cross-platform Flutter/Dart apps.

---

## 🏗️ Architecture & Envelope Flowchart

The `ConnectedNodeEnvelope` sits between local edge devices (desktop, mobile, TV, IoT home nodes) to provide zero-copy Protobuf serialization, frame integrity, and security handshakes:

```text
┌────────────────────────┐                    ┌────────────────────────┐
│      Node A (Mac)      │                    │     Node B (Phone)     │
│ ┌────────────────────┐ │   ConnectedNode    │ ┌────────────────────┐ │
│ │ Payload (Protobuf) │ │    Envelope        │ │ Payload (Protobuf) │ │
│ └─────────┬──────────┘ │ ─────────────────> │ └─────────▲──────────┘ │
│           │            │  (TCP Socket /     │           │            │
│ ┌─────────▼──────────┐ │   WebSockets /     │ ┌─────────┴──────────┐ │
│ │  Socket Transport  │ │   WebRTC Channel)  │ │  Socket Transport  │ │
│ └────────────────────┘ │                    │ └────────────────────┘ │
└────────────────────────┘                    └────────────────────────┘
```

---

## ⚡ Quick Start: Socket Transport & Stream Buffering

### 1. Plug-and-Play TCP Socket Transport Engine

Expose incoming binary frames directly into a Flutter-friendly `Stream`:

```dart
import 'dart:io';
import 'package:core_protocol/core_protocol.dart';

final socket = await Socket.connect('192.168.1.50', 8080);

final transportEngine = AiroSocketTransportEngine();
transportEngine.bind(
  rawInputStream: socket,
  outgoingSink: socket,
);

// Listen to incoming length-prefixed frames
transportEngine.incomingStream.listen((Uint8List payload) {
  print('Received envelope payload bytes: ${payload.length}');
});

// Send outgoing binary frame
final payload = Uint8List.fromList([1, 2, 3, 4]);
transportEngine.send(payload);
```

### 2. Automatic Reconnection Buffer

Queue outgoing messages when network dropouts occur and flush them automatically upon reconnection:

```dart
final buffer = AiroReconnectionBuffer(maxCapacity: 100);

// Sends immediately if connected, or enqueues if offline
buffer.sendOrEnqueue(transportEngine, payload);

// Upon reconnecting:
if (transportEngine.state == AiroTransportConnectionState.connected) {
  final flushedCount = buffer.flush(transportEngine);
  print('Flushed $flushedCount enqueued messages.');
}
```

---

## 📋 Scope & Capabilities

- **Stable Node Identity Records**: Cryptographically verifiable device IDs and trust assertions.
- **Node Lifecycle States**: Paired, connected, revoked, suspended, or unauthenticated lifecycle policies.
- **Privacy-Safe Capability Advertisements**: Device capability matrices without exposing sensitive media data.
- **Length-Prefixed Binary Framing**: Fast, Big-Endian unsigned integer header framing for sockets.
- **Automatic Reconnection Buffer Queueing**: Resilience against local wireless dropouts.
- **Secure Transport Policy Validation**: Replay prevention, frame size caps, and timestamp checks.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
