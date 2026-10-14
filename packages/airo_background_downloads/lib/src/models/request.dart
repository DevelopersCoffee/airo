import 'package:flutter/foundation.dart';

import 'checksum.dart';
import 'policy.dart';

/// Application-supplied transfer request descriptor.
@immutable
class AiroDownloadRequest {
  const AiroDownloadRequest({
    required this.id,
    required this.url,
    required this.destination,
    this.expectedBytes,
    this.checksum,
    this.policy = const AiroDownloadPolicy(),
    this.headers = const {},
    this.overwrite = false,
  });

  final String id;
  final Uri url;
  final String destination;
  final int? expectedBytes;
  final AiroChecksum? checksum;
  final AiroDownloadPolicy policy;
  final Map<String, String> headers;
  final bool overwrite;

  Map<String, Object> toMap() {
    final bytes = expectedBytes;
    final check = checksum;
    return {
      'id': id,
      'url': url.toString(),
      'destination': destination,
      'expectedBytes': ?bytes,
      'checksum': ?check?.toMap(),
      'policy': policy.toMap(),
      'headers': headers,
      'overwrite': overwrite,
    };
  }

  factory AiroDownloadRequest.fromMap(Map<Object?, Object?> map) {
    return AiroDownloadRequest(
      id: map['id'] as String? ?? '',
      url: Uri.parse(map['url'] as String? ?? ''),
      destination: map['destination'] as String? ?? '',
      expectedBytes: (map['expectedBytes'] as num?)?.toInt(),
      checksum: map['checksum'] is Map
          ? AiroChecksum.fromMap(
              (map['checksum'] as Map).cast<Object?, Object?>(),
            )
          : null,
      policy: map['policy'] is Map
          ? AiroDownloadPolicy.fromMap(
              (map['policy'] as Map).cast<Object?, Object?>(),
            )
          : const AiroDownloadPolicy(),
      headers: (map['headers'] as Map?)?.cast<String, String>() ?? const {},
      overwrite: map['overwrite'] as bool? ?? false,
    );
  }
}
