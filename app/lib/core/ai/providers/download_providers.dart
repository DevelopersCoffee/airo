import 'dart:async';
import 'package:core_ai/core_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Provider for the ModelDownloadService.
final modelDownloadServiceProvider = Provider<ModelDownloadService>((ref) {
  final service = ModelDownloadService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// StateNotifier that listens to all model downloads.
class ModelDownloadNotifier
    extends StateNotifier<Map<String, ModelDownloadProgress>> {
  ModelDownloadNotifier(this._service) : super(const {}) {
    _subscription = _service.globalProgressStream.listen((progress) {
      state = {...state, progress.modelId: progress};
    });
  }

  final ModelDownloadService _service;
  StreamSubscription? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider tracking the progress maps of all downloads.
final modelDownloadStateProvider =
    StateNotifierProvider<
      ModelDownloadNotifier,
      Map<String, ModelDownloadProgress>
    >((ref) {
      final service = ref.watch(modelDownloadServiceProvider);
      return ModelDownloadNotifier(service);
    });
