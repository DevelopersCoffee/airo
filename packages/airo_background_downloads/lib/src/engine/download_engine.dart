import 'dart:async';

import '../models/capabilities.dart';
import '../models/download.dart';
import '../models/request.dart';
import '../platform/platform_bridge.dart';
import '../processors/processor.dart';

/// Central transfer engine controlling background downloads, state streams, and pipeline processors.
class AiroDownloadEngine {
  AiroDownloadEngine({
    AiroPlatformBridge? bridge,
    List<AiroDownloadProcessor>? processors,
  }) : _bridge = bridge ?? AiroPlatformBridge(),
       _processors = List.unmodifiable(processors ?? []);

  final AiroPlatformBridge _bridge;
  final List<AiroDownloadProcessor> _processors;

  /// Live transfer state event stream.
  Stream<AiroDownload> get events => _bridge.events;

  /// Enqueues a new application transfer request.
  Future<void> enqueue(AiroDownloadRequest request) async {
    final availableBytes = await _bridge.getAvailableBytes();
    if (availableBytes != null && request.expectedBytes != null) {
      final requirement = AiroStorageRequirement(
        downloadBytes: request.expectedBytes!,
      );
      if (availableBytes < requirement.totalRequiredBytes) {
        throw StateError(
          'Insufficient disk space for transfer artifact "${request.id}". Required: ${requirement.totalRequiredBytes} bytes, Available: $availableBytes bytes.',
        );
      }
    }
    await _bridge.enqueue(request);
  }

  /// Pauses an active transfer.
  Future<void> pause(String id) async => _bridge.pause(id);

  /// Resumes a paused transfer.
  Future<void> resume(String id) async => _bridge.resume(id);

  /// Retries a failed transfer.
  Future<void> retry(String id) async => _bridge.retry(id);

  /// Cancels an active or queued transfer.
  Future<void> cancel(String id) async => _bridge.cancel(id);

  /// Queries a specific transfer by application ID.
  Future<AiroDownload?> get(String id) async => _bridge.get(id);

  /// Queries all transfers across persistent native state.
  Future<List<AiroDownload>> getAll() async => _bridge.getAll();

  /// Queries active downloading or queued transfers.
  Future<List<AiroDownload>> getActiveDownloads() async {
    final all = await getAll();
    return all
        .where(
          (d) =>
              d.status == AiroDownloadStatus.downloading ||
              d.status == AiroDownloadStatus.queued ||
              d.status == AiroDownloadStatus.preparing ||
              d.status == AiroDownloadStatus.waitingForNetwork ||
              d.status == AiroDownloadStatus.waitingForPower,
        )
        .toList();
  }

  /// Queries completed transfers.
  Future<List<AiroDownload>> getCompletedDownloads() async {
    final all = await getAll();
    return all.where((d) => d.status == AiroDownloadStatus.completed).toList();
  }

  /// Queries platform capabilities.
  Future<AiroPlatformCapabilities> capabilities() async =>
      _bridge.capabilities();

  /// Runs configured post-processing pipeline on a completed file.
  Future<AiroProcessorResult> runProcessors(
    AiroDownload download,
    String filePath,
  ) async {
    var currentPath = filePath;
    for (final processor in _processors) {
      final context = AiroProcessorContext(
        download: download,
        filePath: currentPath,
      );
      final result = await processor.process(context);
      if (!result.success) {
        return result;
      }
      currentPath = result.outputFilePath;
    }
    return AiroProcessorResult(success: true, outputFilePath: currentPath);
  }
}
