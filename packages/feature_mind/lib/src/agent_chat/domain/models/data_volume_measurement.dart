import 'package:flutter/foundation.dart';

/// A measured, not asserted, account of how much data a tool call moved.
///
/// The design's example reads "412 notes replayed from the log · 0 bytes
/// left this device". [opsInLog] and [replayedOpSequence] come from an
/// actual `OperationLogPort` read; when neither is available the summary
/// falls back to the raw byte count moved through the connector, so the
/// card never prints a figure nobody measured.
@immutable
class DataVolumeMeasurement {
  const DataVolumeMeasurement({
    required this.bytesProcessed,
    required this.bytesLeftDevice,
    this.opsInLog,
    this.replayedOpSequence,
  });

  /// Bytes of request + response the connector call actually moved.
  final int bytesProcessed;

  /// Bytes that left this device to complete the call. Zero for every
  /// connector that never opens a network client.
  final int bytesLeftDevice;

  /// The log's total op count at the moment this call resolved a citation.
  final int? opsInLog;

  /// The op this call's answer was replayed from, when one was resolved.
  final int? replayedOpSequence;

  String get summary {
    final prefix = (opsInLog != null && replayedOpSequence != null)
        ? '$opsInLog ops in log · replayed op $replayedOpSequence'
        : '$bytesProcessed bytes processed locally';
    return '$prefix · $bytesLeftDevice bytes left this device';
  }

  @override
  bool operator ==(Object other) =>
      other is DataVolumeMeasurement &&
      other.bytesProcessed == bytesProcessed &&
      other.bytesLeftDevice == bytesLeftDevice &&
      other.opsInLog == opsInLog &&
      other.replayedOpSequence == replayedOpSequence;

  @override
  int get hashCode => Object.hash(
    bytesProcessed,
    bytesLeftDevice,
    opsInLog,
    replayedOpSequence,
  );
}
