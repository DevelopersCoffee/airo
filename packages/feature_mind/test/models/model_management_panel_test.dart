import 'dart:async';

import 'package:feature_mind/src/models/model_download_connectivity.dart';
import 'package:feature_mind/src/models/model_management_panel.dart';
import 'package:feature_mind/src/runtime/models/model_models.dart';
import 'package:feature_mind/src/runtime/ports/model_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeModelPort implements ModelPort {
  _FakeModelPort({required this.mindModels, required this.storageResult});

  List<MindModel> mindModels;
  ({int usedBytes, int budgetBytes}) storageResult;
  Object? unloadError;
  Object? benchError;
  ModelBench? nextBench;
  Future<ModelBench>? pendingBench;

  final _downloadControllers =
      <String, StreamController<({int received, int total})>>{};

  StreamController<({int received, int total})> controllerFor(String id) =>
      _downloadControllers.putIfAbsent(
        id,
        () => StreamController<({int received, int total})>.broadcast(),
      );

  @override
  Future<List<MindModel>> all() async => mindModels;

  @override
  Future<({int budgetBytes, int usedBytes})> storage() async => storageResult;

  @override
  Future<void> load(String modelId) async {}

  @override
  Future<void> unload(String modelId) async {
    final error = unloadError;
    if (error != null) throw error;
  }

  @override
  Stream<({int received, int total})> download(String modelId) =>
      controllerFor(modelId).stream;

  @override
  Future<ModelBench> benchmark(String modelId) async {
    final error = benchError;
    if (error != null) throw error;
    final pending = pendingBench;
    if (pending != null) return pending;
    return nextBench ?? (throw UnimplementedError());
  }

  @override
  Stream<ThermalState> thermal() => const Stream.empty();
}

class _FakeConnectivity implements ModelDownloadConnectivity {
  _FakeConnectivity({bool metered = false}) : _metered = metered;

  bool _metered;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isMetered() async => _metered;

  @override
  Stream<bool> get onMeteredChanged => _controller.stream;
}

const _availableModel = MindModel(
  id: 'phi_4_mini',
  name: 'Phi-4 mini',
  sizeBytes: 300,
  residency: ModelResidency.available,
);

const _residentModel = MindModel(
  id: 'whisper_base',
  name: 'Whisper base',
  sizeBytes: 200,
  residency: ModelResidency.resident,
  heldBy: 'Audio Scribe',
);

void main() {
  testWidgets('shows the storage budget as used of total, in bytes', (
    tester,
  ) async {
    final port = _FakeModelPort(
      mindModels: const [_availableModel],
      storageResult: (usedBytes: 100, budgetBytes: 1000),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelManagementPanel(
            models: port,
            connectivity: _FakeConnectivity(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('100 B of 1000 B'), findsOneWidget);
  });

  testWidgets('refuses a download over budget, naming the shortfall', (
    tester,
  ) async {
    final port = _FakeModelPort(
      mindModels: const [_availableModel],
      // 100 available, model is 300: 200 bytes short.
      storageResult: (usedBytes: 900, budgetBytes: 1000),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelManagementPanel(
            models: port,
            connectivity: _FakeConnectivity(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(
      find.text('Not enough storage. Free up 200 B to download this model.'),
      findsOneWidget,
    );
  });

  testWidgets('states the mobile-data pause on the row, not silently', (
    tester,
  ) async {
    final port = _FakeModelPort(
      mindModels: const [_availableModel],
      storageResult: (usedBytes: 0, budgetBytes: 1000),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelManagementPanel(
            models: port,
            connectivity: _FakeConnectivity(metered: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Paused — mobile data'), findsOneWidget);
    expect(find.text('Download anyway'), findsOneWidget);
  });

  testWidgets('an eviction that breaks a capability names it', (tester) async {
    final port =
        _FakeModelPort(
            mindModels: const [_residentModel],
            storageResult: (usedBytes: 200, budgetBytes: 1000),
          )
          ..unloadError = StateError(
            'Unloading Whisper base would break Audio Scribe.',
          );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelManagementPanel(
            models: port,
            connectivity: _FakeConnectivity(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Held by Audio Scribe'), findsOneWidget);

    await tester.tap(find.text('Unload'));
    await tester.pumpAndSettle();

    expect(find.textContaining('would break Audio Scribe'), findsOneWidget);
  });

  testWidgets('distinguishes loaded, resident, and available badges', (
    tester,
  ) async {
    const loaded = MindModel(
      id: 'a',
      name: 'A',
      sizeBytes: 1,
      residency: ModelResidency.loaded,
    );
    final port = _FakeModelPort(
      mindModels: const [loaded, _residentModel, _availableModel],
      storageResult: (usedBytes: 0, budgetBytes: 1000),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelManagementPanel(
            models: port,
            connectivity: _FakeConnectivity(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Loaded'), findsOneWidget);
    expect(find.text('Resident'), findsOneWidget);
    expect(find.text('Available to download'), findsOneWidget);
  });

  testWidgets('Run bench shows tok/s after ModelPort.benchmark resolves', (
    tester,
  ) async {
    final pending = Completer<ModelBench>();
    final port = _FakeModelPort(
      mindModels: const [_residentModel],
      storageResult: (usedBytes: 200, budgetBytes: 1000),
    )..pendingBench = pending.future;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelManagementPanel(
            models: port,
            connectivity: _FakeConnectivity(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Run bench'));
    await tester.pump();
    expect(find.text('Measuring…'), findsOneWidget);

    pending.complete(
      ModelBench(
        tokensPerSecond: 21.5,
        firstTokenMs: 120,
        residentBytes: 200,
        batteryPercentPerHour: 0,
        measuredUnder: ThermalState.nominal,
        measuredAtMs: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('21.5 tok/s · 120 ms to first token'), findsOneWidget);
  });

  testWidgets(
    'Run bench names an unavailable engine instead of inventing tok/s',
    (tester) async {
      final port = _FakeModelPort(
        mindModels: const [_residentModel],
        storageResult: (usedBytes: 200, budgetBytes: 1000),
      )..benchError = StateError('generation engine is not loaded');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModelManagementPanel(
              models: port,
              connectivity: _FakeConnectivity(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Run bench'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bench unavailable:'), findsOneWidget);
      expect(
        find.textContaining('generation engine is not loaded'),
        findsOneWidget,
      );
    },
  );
}
