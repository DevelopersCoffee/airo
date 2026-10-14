import 'package:flutter/foundation.dart';

/// Network policy intent for background transfers.
enum NetworkPolicy { any, unmetered, connected }

/// Power policy intent for background transfers.
enum PowerPolicy { any, charging }

/// Retry backoff policy strategy.
enum RetryPolicy { none, linear, exponential }

/// Portable configuration describing execution policy intent.
@immutable
class AiroDownloadPolicy {
  const AiroDownloadPolicy({
    this.network = NetworkPolicy.any,
    this.power = PowerPolicy.any,
    this.allowMetered = true,
    this.maxRetries = 3,
    this.retryPolicy = RetryPolicy.exponential,
  });

  final NetworkPolicy network;
  final PowerPolicy power;
  final bool allowMetered;
  final int maxRetries;
  final RetryPolicy retryPolicy;

  Map<String, Object> toMap() => {
    'network': network.name,
    'power': power.name,
    'allowMetered': allowMetered,
    'maxRetries': maxRetries,
    'retryPolicy': retryPolicy.name,
  };

  factory AiroDownloadPolicy.fromMap(Map<Object?, Object?> map) {
    return AiroDownloadPolicy(
      network: NetworkPolicy.values.firstWhere(
        (e) => e.name == map['network'],
        orElse: () => NetworkPolicy.any,
      ),
      power: PowerPolicy.values.firstWhere(
        (e) => e.name == map['power'],
        orElse: () => PowerPolicy.any,
      ),
      allowMetered: map['allowMetered'] as bool? ?? true,
      maxRetries: (map['maxRetries'] as num?)?.toInt() ?? 3,
      retryPolicy: RetryPolicy.values.firstWhere(
        (e) => e.name == map['retryPolicy'],
        orElse: () => RetryPolicy.exponential,
      ),
    );
  }
}
