import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/checksum.dart';

/// Computes a lowercase hex digest for [file] using chunked reads.
Future<String> streamingChecksumHex(
  File file,
  AiroChecksumAlgorithm algorithm,
) async {
  final stream = file.openRead();
  final Digest digest = switch (algorithm) {
    AiroChecksumAlgorithm.sha256 => await sha256.bind(stream).first,
    AiroChecksumAlgorithm.sha1 => await sha1.bind(stream).first,
    AiroChecksumAlgorithm.md5 => await md5.bind(stream).first,
  };
  return digest.toString();
}

/// Returns `true` when [file]'s digest matches [checksum] (hex, case-insensitive).
Future<bool> fileMatchesChecksum(File file, AiroChecksum checksum) async {
  if (!await file.exists() || await file.length() == 0) {
    return false;
  }
  final actual = await streamingChecksumHex(file, checksum.algorithm);
  return actual.toLowerCase() == checksum.value.trim().toLowerCase();
}

/// Verifies [file] against a normalized lowercase SHA-256 hex string.
Future<bool> fileMatchesSha256Hex(File file, String expectedHex) async {
  return fileMatchesChecksum(
    file,
    AiroChecksum(algorithm: AiroChecksumAlgorithm.sha256, value: expectedHex),
  );
}
