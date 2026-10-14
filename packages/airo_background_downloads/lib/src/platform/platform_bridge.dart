import 'dart:async';

import 'package:flutter/services.dart';

import '../models/capabilities.dart';
import '../models/download.dart';
import '../models/request.dart';

/// Platform bridge executing intent policies against native Android WorkManager & iOS URLSession.
class AiroPlatformBridge {
  static const MethodChannel _methods = MethodChannel(
    'dev.airo.platform_downloads/methods',
  );
  static const EventChannel _events = EventChannel(
    'dev.airo.platform_downloads/events',
  );

  Stream<AiroDownload>? _eventStream;

  Stream<AiroDownload> get events {
    return _eventStream ??= _events
        .receiveBroadcastStream()
        .where((e) => e is Map)
        .map((e) => AiroDownload.fromMap((e as Map).cast<Object?, Object?>()));
  }

  Future<void> enqueue(AiroDownloadRequest request) async {
    await _methods.invokeMethod('enqueue', request.toMap());
  }

  Future<void> pause(String id) async {
    await _methods.invokeMethod('pause', {'artifactId': id});
  }

  Future<void> resume(String id) async {
    await _methods.invokeMethod('resume', {'artifactId': id});
  }

  Future<void> retry(String id) async {
    await _methods.invokeMethod('retry', {'artifactId': id});
  }

  Future<void> cancel(String id) async {
    await _methods.invokeMethod('cancel', {'artifactId': id});
  }

  Future<AiroDownload?> get(String id) async {
    final list = await getAll();
    final matches = list.where((d) => d.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  Future<List<AiroDownload>> getAll() async {
    final raw = await _methods.invokeMethod<Map>('getQueue');
    if (raw == null) return [];
    final entries = raw['entries'];
    if (entries is! List) return [];
    return List<AiroDownload>.unmodifiable(
      entries.whereType<Map>().map(
        (e) => AiroDownload.fromMap(e.cast<Object?, Object?>()),
      ),
    );
  }

  Future<int?> getAvailableBytes() async {
    return await _methods.invokeMethod<int>('getAvailableBytes');
  }

  Future<AiroPlatformCapabilities> capabilities() async {
    return const AiroPlatformCapabilities(
      backgroundDownloads: true,
      pauseResume: true,
      networkConstraints: true,
      chargingConstraints: true,
      checksumVerification: true,
      backgroundProcessing: true,
      notifications: true,
    );
  }
}
