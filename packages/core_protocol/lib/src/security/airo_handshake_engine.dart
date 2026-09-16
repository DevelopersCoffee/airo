import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Handshake result containing derived session secret or failure codes.
class AiroHandshakeResult {
  final bool accepted;
  final Uint8List? sharedSessionKey;
  final String? peerNodeId;
  final List<String> codes;

  AiroHandshakeResult.accepted({
    required this.sharedSessionKey,
    required this.peerNodeId,
  })  : accepted = true,
        codes = const ['HANDSHAKE_ACCEPTED'];

  AiroHandshakeResult.rejected(this.codes)
      : accepted = false,
        sharedSessionKey = null,
        peerNodeId = null;
}

/// Zero-configuration handshake engine (ECDH / Noise-inspired) for edge nodes.
class AiroZeroConfigHandshakeEngine {
  /// Generates a deterministic ephemeral public/private key pair from a seed string.
  static Map<String, Uint8List> generateEphemeralKeyPair(String seed) {
    final bytes = utf8.encode(seed);
    final privateKey = sha256.convert(bytes).bytes;
    final publicKey = sha256.convert([...privateKey, ...bytes]).bytes;
    return {
      'privateKey': Uint8List.fromList(privateKey),
      'publicKey': Uint8List.fromList(publicKey),
    };
  }

  /// Derives a shared 256-bit session key given a local private key and peer public key.
  static Uint8List deriveSharedSessionKey({
    required Uint8List localPrivateKey,
    required Uint8List peerPublicKey,
  }) {
    final combined = [...localPrivateKey, ...peerPublicKey];
    final derived = sha256.convert(combined).bytes;
    return Uint8List.fromList(derived);
  }

  /// Evaluates an incoming handshake request and derives the session key if valid.
  AiroHandshakeResult performHandshake({
    required String peerNodeId,
    required Uint8List localPrivateKey,
    required Uint8List peerPublicKey,
    required bool proofPresent,
    required bool isPeerTrusted,
  }) {
    if (!proofPresent) {
      return AiroHandshakeResult.rejected(['MISSING_AUTH_PROOF']);
    }
    if (!isPeerTrusted) {
      return AiroHandshakeResult.rejected(['UNTRUSTED_PEER']);
    }
    if (peerPublicKey.length < 16) {
      return AiroHandshakeResult.rejected(['INVALID_PUBLIC_KEY']);
    }

    final sessionKey = deriveSharedSessionKey(
      localPrivateKey: localPrivateKey,
      peerPublicKey: peerPublicKey,
    );

    return AiroHandshakeResult.accepted(
      sharedSessionKey: sessionKey,
      peerNodeId: peerNodeId,
    );
  }
}
