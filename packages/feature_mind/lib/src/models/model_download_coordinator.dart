import 'dart:async';

import '../runtime/ports/model_port.dart';
import 'model_download_connectivity.dart';
import 'model_download_state.dart';

/// Orchestrates one model download against [ModelPort]: refuses a download
/// that would overrun the storage budget before it starts, and shows an
/// explicit paused-for-metered state — rather than a silent stall — while the
/// device is on mobile data, resuming on its own once it is not.
///
/// [ModelPort.download]'s own contract already says the port "pauses on
/// metered connections; the stream stalls rather than erroring" — but a
/// stalled stream and a hung one look identical to whatever is watching it.
/// This coordinator does not rely on that alone: it watches connectivity
/// directly, so a caller always gets a state that names the reason, even if
/// the underlying port never emits anything while paused.
class ModelDownloadCoordinator {
  ModelDownloadCoordinator({required this.models, required this.connectivity});

  final ModelPort models;
  final ModelDownloadConnectivity connectivity;

  /// Emits the states of downloading [modelId], whose full size is
  /// [sizeBytes] — read from [ModelPort.all] by the caller, since the port
  /// exposes size on [MindModel], not on `download` itself.
  ///
  /// [allowMetered] is the user's explicit override ("Download anyway"): when
  /// true, a metered connection never pauses this download. Cancelling the
  /// returned stream's subscription cancels the underlying download and
  /// connectivity subscriptions; nothing here keeps running unobserved.
  Stream<ModelDownloadState> download(
    String modelId, {
    required int sizeBytes,
    bool allowMetered = false,
  }) {
    late final StreamController<ModelDownloadState> controller;
    StreamSubscription<({int received, int total})>? downloadSub;
    StreamSubscription<bool>? meteredSub;
    var metered = false;
    var received = 0;
    var closed = false;

    void emit(ModelDownloadState state) {
      if (!closed && !controller.isClosed) controller.add(state);
    }

    Future<void> close() async {
      if (closed) return;
      closed = true;
      await downloadSub?.cancel();
      await meteredSub?.cancel();
      await controller.close();
    }

    void startDownload() {
      downloadSub = models.download(modelId).listen(
        (progress) {
          received = progress.received;
          if (metered && !allowMetered) {
            emit(
              ModelDownloadPausedForMetered(
                received: progress.received,
                total: progress.total,
              ),
            );
            return;
          }
          if (progress.total > 0 && progress.received >= progress.total) {
            emit(const ModelDownloadCompleted());
            unawaited(close());
            return;
          }
          emit(
            ModelDownloadInProgress(
              received: progress.received,
              total: progress.total,
            ),
          );
        },
        onError: (Object error, StackTrace _) {
          emit(ModelDownloadFailed(error.toString()));
          unawaited(close());
        },
        onDone: () {
          if (!closed) {
            emit(const ModelDownloadCompleted());
            unawaited(close());
          }
        },
      );
    }

    controller = StreamController<ModelDownloadState>(
      onListen: () {
        unawaited(() async {
          emit(const ModelDownloadCheckingStorage());
          final ({int budgetBytes, int usedBytes}) storage;
          try {
            storage = await models.storage();
          } on Object catch (error) {
            emit(ModelDownloadFailed(error.toString()));
            await close();
            return;
          }
          if (closed) return;

          final availableBytes = storage.budgetBytes - storage.usedBytes;
          if (sizeBytes > availableBytes) {
            emit(
              ModelDownloadInsufficientStorage(
                shortfallBytes: sizeBytes - availableBytes,
              ),
            );
            await close();
            return;
          }

          try {
            metered = allowMetered ? false : await connectivity.isMetered();
          } on Object {
            // Connectivity is a courtesy check, not the download itself — an
            // unknown network type must not block a download the storage
            // budget already approved.
            metered = false;
          }
          if (closed) return;

          meteredSub = connectivity.onMeteredChanged.listen((isMetered) {
            metered = allowMetered ? false : isMetered;
            if (closed) return;
            if (metered) {
              emit(
                ModelDownloadPausedForMetered(
                  received: received,
                  total: sizeBytes,
                ),
              );
            } else {
              emit(
                ModelDownloadInProgress(received: received, total: sizeBytes),
              );
            }
          });

          if (metered) {
            emit(
              ModelDownloadPausedForMetered(received: 0, total: sizeBytes),
            );
          }
          startDownload();
        }());
      },
      onCancel: close,
    );
    return controller.stream;
  }
}
