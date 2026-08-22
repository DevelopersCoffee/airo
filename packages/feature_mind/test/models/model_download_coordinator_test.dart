import 'dart:async';

import 'package:feature_mind/src/models/model_download_connectivity.dart';
import 'package:feature_mind/src/models/model_download_coordinator.dart';
import 'package:feature_mind/src/models/model_download_state.dart';
import 'package:feature_mind/src/runtime/models/model_models.dart';
import 'package:feature_mind/src/runtime/ports/model_port.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [ModelPort] test double. Only `storage` and `download` are exercised —
/// the coordinator does not touch the rest of the port.
class FakeModelPort implements ModelPort {
  FakeModelPort({
    this.usedBytes = 0,
    this.budgetBytes = 1000,
    this.storageError,
  });

  int usedBytes;
  int budgetBytes;
  final Object? storageError;

  final _downloadControllers =
      <String, StreamController<({int received, int total})>>{};

  StreamController<({int received, int total})> controllerFor(String modelId) =>
      _downloadControllers.putIfAbsent(
        modelId,
        () => StreamController<({int received, int total})>.broadcast(),
      );

  var downloadCallCount = 0;

  @override
  Future<({int budgetBytes, int usedBytes})> storage() async {
    if (storageError != null) throw storageError!;
    return (usedBytes: usedBytes, budgetBytes: budgetBytes);
  }

  @override
  Stream<({int received, int total})> download(String modelId) {
    downloadCallCount++;
    return controllerFor(modelId).stream;
  }

  @override
  Future<List<MindModel>> all() async => [];

  @override
  Future<void> load(String modelId) async {}

  @override
  Future<void> unload(String modelId) async {}

  @override
  Future<ModelBench> benchmark(String modelId) async =>
      throw UnimplementedError();

  @override
  Stream<ThermalState> thermal() => const Stream.empty();
}

class FakeConnectivity implements ModelDownloadConnectivity {
  FakeConnectivity({bool metered = false}) : _metered = metered;

  bool _metered;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isMetered() async => _metered;

  @override
  Stream<bool> get onMeteredChanged => _controller.stream;

  void setMetered(bool value) {
    _metered = value;
    _controller.add(value);
  }

  void dispose() => _controller.close();
}

void main() {
  group('storage budget', () {
    test('refuses a download that would overrun the budget', () async {
      final port = FakeModelPort(usedBytes: 900, budgetBytes: 1000);
      final coordinator = ModelDownloadCoordinator(
        models: port,
        connectivity: FakeConnectivity(),
      );

      final states = await coordinator.download('m1', sizeBytes: 300).toList();

      expect(states.first, const ModelDownloadCheckingStorage());
      // Available is 100, requested is 300: 200 bytes short.
      expect(
        states.last,
        const ModelDownloadInsufficientStorage(shortfallBytes: 200),
      );
      expect(
        port.downloadCallCount,
        0,
        reason: 'must be refused before it starts',
      );
    });

    test('starts the download when it fits the budget', () async {
      final port = FakeModelPort(usedBytes: 100, budgetBytes: 1000);
      final coordinator = ModelDownloadCoordinator(
        models: port,
        connectivity: FakeConnectivity(),
      );

      final states = <ModelDownloadState>[];
      final sub = coordinator.download('m1', sizeBytes: 300).listen(states.add);
      await Future<void>.delayed(Duration.zero);

      expect(port.downloadCallCount, 1);
      port.controllerFor('m1').add((received: 150, total: 300));
      await Future<void>.delayed(Duration.zero);

      expect(
        states,
        contains(const ModelDownloadInProgress(received: 150, total: 300)),
      );
      await sub.cancel();
    });

    test('a storage read failure surfaces as a named failure', () async {
      final port = FakeModelPort(storageError: StateError('disk unavailable'));
      final coordinator = ModelDownloadCoordinator(
        models: port,
        connectivity: FakeConnectivity(),
      );

      final states = await coordinator.download('m1', sizeBytes: 300).toList();

      expect(states.last, isA<ModelDownloadFailed>());
      expect(
        (states.last as ModelDownloadFailed).reason,
        contains('disk unavailable'),
      );
    });
  });

  group('mobile-data pause', () {
    test('starts paused, stated on the row, when already metered', () async {
      final port = FakeModelPort(usedBytes: 0, budgetBytes: 1000);
      final coordinator = ModelDownloadCoordinator(
        models: port,
        connectivity: FakeConnectivity(metered: true),
      );

      final states = <ModelDownloadState>[];
      final sub = coordinator.download('m1', sizeBytes: 300).listen(states.add);
      await Future<void>.delayed(Duration.zero);

      expect(
        states,
        contains(const ModelDownloadPausedForMetered(received: 0, total: 300)),
      );
      await sub.cancel();
    });

    test('pauses mid-download when the connection becomes metered', () async {
      final port = FakeModelPort(usedBytes: 0, budgetBytes: 1000);
      final connectivity = FakeConnectivity();
      final coordinator = ModelDownloadCoordinator(
        models: port,
        connectivity: connectivity,
      );

      final states = <ModelDownloadState>[];
      final sub = coordinator.download('m1', sizeBytes: 300).listen(states.add);
      await Future<void>.delayed(Duration.zero);

      port.controllerFor('m1').add((received: 100, total: 300));
      await Future<void>.delayed(Duration.zero);
      expect(
        states.last,
        const ModelDownloadInProgress(received: 100, total: 300),
      );

      connectivity.setMetered(true);
      await Future<void>.delayed(Duration.zero);

      expect(
        states.last,
        const ModelDownloadPausedForMetered(received: 100, total: 300),
      );

      // A progress tick that arrives while still metered stays paused, not
      // silently downloading — the underlying port may keep emitting even
      // while it "stalls".
      port.controllerFor('m1').add((received: 120, total: 300));
      await Future<void>.delayed(Duration.zero);
      expect(
        states.last,
        const ModelDownloadPausedForMetered(received: 120, total: 300),
      );

      await sub.cancel();
      connectivity.dispose();
    });

    test('resumes automatically once the connection is unmetered', () async {
      final port = FakeModelPort(usedBytes: 0, budgetBytes: 1000);
      final connectivity = FakeConnectivity(metered: true);
      final coordinator = ModelDownloadCoordinator(
        models: port,
        connectivity: connectivity,
      );

      final states = <ModelDownloadState>[];
      final sub = coordinator.download('m1', sizeBytes: 300).listen(states.add);
      await Future<void>.delayed(Duration.zero);
      expect(states.last, isA<ModelDownloadPausedForMetered>());

      connectivity.setMetered(false);
      await Future<void>.delayed(Duration.zero);
      expect(states.last, isA<ModelDownloadInProgress>());

      port.controllerFor('m1').add((received: 300, total: 300));
      await Future<void>.delayed(Duration.zero);
      expect(states.last, const ModelDownloadCompleted());

      await sub.cancel();
      connectivity.dispose();
    });

    test('allowMetered downloads on mobile data without pausing', () async {
      final port = FakeModelPort(usedBytes: 0, budgetBytes: 1000);
      final coordinator = ModelDownloadCoordinator(
        models: port,
        connectivity: FakeConnectivity(metered: true),
      );

      final states = <ModelDownloadState>[];
      final sub = coordinator
          .download('m1', sizeBytes: 300, allowMetered: true)
          .listen(states.add);
      await Future<void>.delayed(Duration.zero);

      expect(states.any((s) => s is ModelDownloadPausedForMetered), isFalse);

      port.controllerFor('m1').add((received: 300, total: 300));
      await Future<void>.delayed(Duration.zero);
      expect(states.last, const ModelDownloadCompleted());

      await sub.cancel();
    });
  });

  group('progress and failure', () {
    test(
      'reports bytes of total while downloading, not a bare percentage',
      () async {
        final port = FakeModelPort(usedBytes: 0, budgetBytes: 1000);
        final coordinator = ModelDownloadCoordinator(
          models: port,
          connectivity: FakeConnectivity(),
        );

        final states = <ModelDownloadState>[];
        final sub = coordinator
            .download('m1', sizeBytes: 500)
            .listen(states.add);
        await Future<void>.delayed(Duration.zero);

        port.controllerFor('m1').add((received: 100, total: 500));
        port.controllerFor('m1').add((received: 250, total: 500));
        await Future<void>.delayed(Duration.zero);

        expect(
          states,
          contains(const ModelDownloadInProgress(received: 100, total: 500)),
        );
        expect(
          states,
          contains(const ModelDownloadInProgress(received: 250, total: 500)),
        );

        await sub.cancel();
      },
    );

    test('completes when the port stream reports received == total', () async {
      final port = FakeModelPort(usedBytes: 0, budgetBytes: 1000);
      final coordinator = ModelDownloadCoordinator(
        models: port,
        connectivity: FakeConnectivity(),
      );

      final states = <ModelDownloadState>[];
      final sub = coordinator.download('m1', sizeBytes: 500).listen(states.add);
      await Future<void>.delayed(Duration.zero);

      port.controllerFor('m1').add((received: 500, total: 500));
      await Future<void>.delayed(Duration.zero);

      expect(states.last, const ModelDownloadCompleted());
      await sub.cancel();
    });

    test(
      'a download failure names the reason rather than going silent',
      () async {
        final port = FakeModelPort(usedBytes: 0, budgetBytes: 1000);
        final coordinator = ModelDownloadCoordinator(
          models: port,
          connectivity: FakeConnectivity(),
        );

        final states = <ModelDownloadState>[];
        final sub = coordinator
            .download('m1', sizeBytes: 500)
            .listen(states.add);
        await Future<void>.delayed(Duration.zero);

        port.controllerFor('m1').addError(StateError('connection reset'));
        await Future<void>.delayed(Duration.zero);

        expect(states.last, isA<ModelDownloadFailed>());
        expect(
          (states.last as ModelDownloadFailed).reason,
          contains('connection reset'),
        );
        await sub.cancel();
      },
    );

    test('emits stalled when bytes stop moving for the stall window', () async {
      final port = FakeModelPort(usedBytes: 0, budgetBytes: 1000);
      final coordinator = ModelDownloadCoordinator(
        models: port,
        connectivity: FakeConnectivity(),
        stallThreshold: const Duration(milliseconds: 40),
        stallPollInterval: const Duration(milliseconds: 10),
      );

      final states = <ModelDownloadState>[];
      final sub = coordinator.download('m1', sizeBytes: 500).listen(states.add);
      await Future<void>.delayed(Duration.zero);

      port.controllerFor('m1').add((received: 100, total: 500));
      await Future<void>.delayed(Duration.zero);
      expect(
        states,
        contains(const ModelDownloadInProgress(received: 100, total: 500)),
      );

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(
        states.last,
        const ModelDownloadStalled(received: 100, total: 500),
      );
      await sub.cancel();
    });
  });
}
