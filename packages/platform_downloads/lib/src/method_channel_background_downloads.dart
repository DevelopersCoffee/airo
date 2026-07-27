import 'package:flutter/services.dart';

import 'background_downloads.dart';
import 'download_models.dart';

class MethodChannelBackgroundDownloads implements BackgroundDownloads {
  MethodChannelBackgroundDownloads({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel = methodChannel ?? const MethodChannel(methodChannelName),
       _eventChannel = eventChannel ?? const EventChannel(eventChannelName);

  static const String methodChannelName = 'dev.airo.platform_downloads/methods';
  static const String eventChannelName = 'dev.airo.platform_downloads/events';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  Stream<DownloadProgress>? _events;

  @override
  Stream<DownloadProgress> get events => _events ??= _eventChannel
      .receiveBroadcastStream(<String, Object?>{
        'contractVersion': backgroundDownloadContractVersion,
      })
      .map((event) {
        if (event is! Map) {
          throw const FormatException('Invalid platform download event');
        }
        return DownloadProgress.fromMap(event.cast<Object?, Object?>());
      });

  @override
  Future<void> enqueue(DownloadArtifactRequest request) {
    return _methodChannel.invokeMethod<void>(
      'enqueue',
      request.toPlatformMap(),
    );
  }

  @override
  Future<void> pause(String artifactId) =>
      _invokeArtifactAction('pause', artifactId);

  @override
  Future<void> resume(String artifactId) =>
      _invokeArtifactAction('resume', artifactId);

  @override
  Future<void> retry(String artifactId) =>
      _invokeArtifactAction('retry', artifactId);

  @override
  Future<void> cancel(String artifactId) =>
      _invokeArtifactAction('cancel', artifactId);

  @override
  Future<DownloadQueueSnapshot> getQueue() async {
    final payload = await _methodChannel.invokeMethod<Object?>('getQueue', {
      'contractVersion': backgroundDownloadContractVersion,
    });
    if (payload is! Map) {
      return const DownloadQueueSnapshot(entries: <DownloadProgress>[]);
    }
    return DownloadQueueSnapshot.fromMap(payload.cast<Object?, Object?>());
  }

  @override
  Future<int?> getAvailableBytes() {
    return _methodChannel.invokeMethod<int>('getAvailableBytes', {
      'contractVersion': backgroundDownloadContractVersion,
    });
  }

  Future<void> _invokeArtifactAction(String method, String artifactId) {
    final normalizedId = artifactId.trim();
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(normalizedId)) {
      throw ArgumentError.value(
        artifactId,
        'artifactId',
        'must be a safe 1-128 character identifier',
      );
    }
    return _methodChannel.invokeMethod<void>(method, <String, Object?>{
      'artifactId': normalizedId,
    });
  }
}
