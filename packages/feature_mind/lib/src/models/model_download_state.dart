import 'package:flutter/foundation.dart';

/// What a model download row shows right now.
///
/// A sealed hierarchy rather than one flat class with nullable fields: a
/// screen that pattern-matches on this cannot forget the paused-for-metered
/// or insufficient-storage cases the way it could forget to check a boolean
/// flag. #1457 exists because those two states used to have no
/// representation at all — a stalled download and a failed-at-94% download
/// looked identical to the person watching them.
@immutable
sealed class ModelDownloadState {
  const ModelDownloadState();
}

/// Nothing requested yet.
final class ModelDownloadIdle extends ModelDownloadState {
  const ModelDownloadIdle();

  @override
  bool operator ==(Object other) => other is ModelDownloadIdle;

  @override
  int get hashCode => (ModelDownloadIdle).hashCode;
}

/// The storage budget is being read before anything is enqueued. Brief, but
/// real — a screen that jumps straight to a progress bar with no state in
/// between reads as though the check never happened.
final class ModelDownloadCheckingStorage extends ModelDownloadState {
  const ModelDownloadCheckingStorage();

  @override
  bool operator ==(Object other) => other is ModelDownloadCheckingStorage;

  @override
  int get hashCode => (ModelDownloadCheckingStorage).hashCode;
}

/// Refused before a single byte moved. [shortfallBytes] is how much more
/// free space the device needs, not how large the model is — the number a
/// person acts on is "free up 1.2 GB", not "this model is 6 GB".
final class ModelDownloadInsufficientStorage extends ModelDownloadState {
  const ModelDownloadInsufficientStorage({required this.shortfallBytes});

  final int shortfallBytes;

  @override
  bool operator ==(Object other) =>
      other is ModelDownloadInsufficientStorage &&
      other.shortfallBytes == shortfallBytes;

  @override
  int get hashCode =>
      Object.hash(ModelDownloadInsufficientStorage, shortfallBytes);
}

/// Stopped on a metered connection. Explicit and named on the row itself —
/// the issue's whole complaint about the previous behaviour is that this
/// state was silent, indistinguishable from a stall or a hang.
final class ModelDownloadPausedForMetered extends ModelDownloadState {
  const ModelDownloadPausedForMetered({
    required this.received,
    required this.total,
  });

  final int received;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is ModelDownloadPausedForMetered &&
      other.received == received &&
      other.total == total;

  @override
  int get hashCode =>
      Object.hash(ModelDownloadPausedForMetered, received, total);
}

/// Bytes moving. [received] and [total] are both real byte counts — never a
/// bare percentage, so the row can say "212 MB of 1.9 GB" rather than "11%".
final class ModelDownloadInProgress extends ModelDownloadState {
  const ModelDownloadInProgress({required this.received, required this.total});

  final int received;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is ModelDownloadInProgress &&
      other.received == received &&
      other.total == total;

  @override
  int get hashCode => Object.hash(ModelDownloadInProgress, received, total);
}

/// Platform still reports an active transfer but bytes have not moved for the
/// stall window. Distinct from [ModelDownloadFailed] so the row can offer
/// "Resume download" while naming the hang rather than a generic error.
final class ModelDownloadStalled extends ModelDownloadState {
  const ModelDownloadStalled({required this.received, required this.total});

  final int received;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is ModelDownloadStalled &&
      other.received == received &&
      other.total == total;

  @override
  int get hashCode => Object.hash(ModelDownloadStalled, received, total);
}

final class ModelDownloadCompleted extends ModelDownloadState {
  const ModelDownloadCompleted();

  @override
  bool operator ==(Object other) => other is ModelDownloadCompleted;

  @override
  int get hashCode => (ModelDownloadCompleted).hashCode;
}

/// [reason] names what went wrong. A blank retry button with no explanation
/// is the failure mode this exists to avoid.
final class ModelDownloadFailed extends ModelDownloadState {
  const ModelDownloadFailed(this.reason);

  final String reason;

  @override
  bool operator ==(Object other) =>
      other is ModelDownloadFailed && other.reason == reason;

  @override
  int get hashCode => Object.hash(ModelDownloadFailed, reason);
}
