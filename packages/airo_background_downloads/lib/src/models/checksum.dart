import 'package:flutter/foundation.dart';

/// Supported checksum algorithms for payload verification.
enum AiroChecksumAlgorithm { sha256, sha1, md5 }

/// Integrity checksum descriptor.
@immutable
class AiroChecksum {
  const AiroChecksum({required this.algorithm, required this.value});

  final AiroChecksumAlgorithm algorithm;
  final String value;

  Map<String, Object> toMap() => {'algorithm': algorithm.name, 'value': value};

  factory AiroChecksum.fromMap(Map<Object?, Object?> map) {
    return AiroChecksum(
      algorithm: AiroChecksumAlgorithm.values.firstWhere(
        (e) => e.name == map['algorithm'],
        orElse: () => AiroChecksumAlgorithm.sha256,
      ),
      value: (map['value'] as String? ?? '').trim().toLowerCase(),
    );
  }
}
