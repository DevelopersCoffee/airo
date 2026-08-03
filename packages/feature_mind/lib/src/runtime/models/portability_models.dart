import 'package:flutter/foundation.dart';

/// Where a sealed package can go. None of these is a server, because there
/// isn't one.
enum PackageDestination { lanPeer, thisDevice, usbDrive }

/// One band of the size breakdown — scans, audio, log.
@immutable
class ContentClassSize {
  const ContentClassSize(this.label, this.bytes);

  final String label;
  final int bytes;

  @override
  bool operator ==(Object other) =>
      other is ContentClassSize && other.label == label && other.bytes == bytes;

  @override
  int get hashCode => Object.hash(label, bytes);
}

/// What sealing would produce, given the contexts currently selected.
///
/// Recomputed on every selection change: a size that does not move when a
/// context is unchecked tells the person their choice did nothing.
@immutable
class RecoveryPackagePlan {
  const RecoveryPackagePlan({
    required this.selectedContextIds,
    required this.breakdown,
    required this.fileName,
  });

  final List<String> selectedContextIds;
  final List<ContentClassSize> breakdown;
  final String fileName;

  int get totalBytes =>
      breakdown.fold(0, (sum, contentClass) => sum + contentClass.bytes);

  @override
  bool operator ==(Object other) =>
      other is RecoveryPackagePlan &&
      listEquals(other.selectedContextIds, selectedContextIds) &&
      listEquals(other.breakdown, breakdown) &&
      other.fileName == fileName;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(selectedContextIds),
    Object.hashAll(breakdown),
    fileName,
  );
}
