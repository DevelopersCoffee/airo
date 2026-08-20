import 'dart:async';

import 'package:flutter/material.dart';

import '../runtime/models/model_models.dart';
import '../runtime/ports/model_port.dart';
import '../widgets/mind_palette.dart';
import 'byte_format.dart';
import 'model_download_connectivity.dart';
import 'model_download_coordinator.dart';
import 'model_download_state.dart';

/// Surface 10's model download manager (#1457): the storage budget, and one
/// row per [MindModel] with its residency, its download progress in bytes,
/// and — when it applies — the mobile-data-pause banner or the eviction
/// warning naming the capability that would break.
///
/// Backs `ModelPort` directly rather than the older `agent_chat` model
/// picker's `core_ai` pipeline: this panel is what a Mind surface reaches for
/// once it only depends on the port `MindRuntime` exposes.
class ModelManagementPanel extends StatefulWidget {
  const ModelManagementPanel({
    super.key,
    required this.models,
    this._connectivity,
  });

  final ModelPort models;
  final ModelDownloadConnectivity? _connectivity;

  @override
  State<ModelManagementPanel> createState() => _ModelManagementPanelState();
}

class _ModelManagementPanelState extends State<ModelManagementPanel> {
  late final ModelDownloadConnectivity _connectivity =
      widget._connectivity ?? ConnectivityPlusModelDownloadConnectivity();
  late final ModelDownloadCoordinator _coordinator = ModelDownloadCoordinator(
    models: widget.models,
    connectivity: _connectivity,
  );

  List<MindModel>? _mindModels;
  ({int usedBytes, int budgetBytes})? _storage;
  Object? _loadError;

  /// One active download's state, by model id. A model absent from this map
  /// has not been asked for and shows its plain "available" row.
  final Map<String, ModelDownloadState> _downloads = {};
  final Map<String, StreamSubscription<ModelDownloadState>> _subscriptions = {};
  final Map<String, _BenchRowState> _benches = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await (widget.models.all(), widget.models.storage()).wait;
      if (!mounted) return;
      setState(() {
        _mindModels = results.$1;
        _storage = results.$2;
        _loadError = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  void _startDownload(MindModel model, {bool allowMetered = false}) {
    unawaited(_subscriptions[model.id]?.cancel());
    _subscriptions[model.id] = _coordinator
        .download(
          model.id,
          sizeBytes: model.sizeBytes,
          allowMetered: allowMetered,
        )
        .listen((state) {
          if (!mounted) return;
          setState(() => _downloads[model.id] = state);
          if (state is ModelDownloadCompleted) unawaited(_load());
        });
  }

  Future<void> _loadModel(MindModel model) async {
    try {
      await widget.models.load(model.id);
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _unload(MindModel model) async {
    try {
      await widget.models.unload(model.id);
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _runBench(MindModel model) async {
    setState(() => _benches[model.id] = const _BenchRowState.running());
    try {
      final bench = await widget.models.benchmark(model.id);
      if (!mounted) return;
      setState(() => _benches[model.id] = _BenchRowState.measured(bench));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _benches[model.id] = _BenchRowState.failed('$error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loadError = _loadError;
    if (loadError != null) {
      return Center(child: Text('Could not load models: $loadError'));
    }
    final mindModels = _mindModels;
    final storage = _storage;
    if (mindModels == null || storage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StorageBudgetBar(storage: storage),
        const SizedBox(height: 16),
        for (final model in mindModels)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ModelDownloadRow(
              model: model,
              downloadState: _downloads[model.id],
              benchState: _benches[model.id],
              onDownload: () => _startDownload(model),
              onDownloadAnyway: () => _startDownload(model, allowMetered: true),
              onUnload: () => _unload(model),
              onLoad: () => _loadModel(model),
              onBenchmark: () => _runBench(model),
            ),
          ),
      ],
    );
  }
}

class _StorageBudgetBar extends StatelessWidget {
  const _StorageBudgetBar({required this.storage});

  final ({int usedBytes, int budgetBytes}) storage;

  @override
  Widget build(BuildContext context) {
    final fraction = storage.budgetBytes > 0
        ? (storage.usedBytes / storage.budgetBytes).clamp(0.0, 1.0)
        : 0.0;
    return Semantics(
      label:
          'Model storage: ${formatBytesOf(storage.usedBytes, storage.budgetBytes)} used',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Model storage', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              color: fraction >= 1.0 ? MindPalette.alarm : MindPalette.local,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatBytesOf(storage.usedBytes, storage.budgetBytes),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// A [MindModel] row: name, residency, and — depending on
/// [downloadState] — its download progress, its mobile-data-pause banner, or
/// its refused-for-storage banner.
class ModelDownloadRow extends StatelessWidget {
  const ModelDownloadRow({
    super.key,
    required this.model,
    required this.downloadState,
    required this.onDownload,
    required this.onDownloadAnyway,
    required this.onUnload,
    this.onLoad,
    this.benchState,
    this.onBenchmark,
  });

  final MindModel model;
  final ModelDownloadState? downloadState;
  final _BenchRowState? benchState;
  final VoidCallback onDownload;
  final VoidCallback onDownloadAnyway;
  final VoidCallback onUnload;
  final VoidCallback? onLoad;
  final VoidCallback? onBenchmark;

  static const Map<ModelResidency, String> _residencyLabels = {
    ModelResidency.loaded: 'Loaded',
    ModelResidency.resident: 'Resident',
    ModelResidency.available: 'Available to download',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = downloadState;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(model.name, style: theme.textTheme.titleSmall),
                ),
                _ResidencyBadge(model: model),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formatBytes(model.sizeBytes),
              style: theme.textTheme.bodySmall,
            ),
            if (model.residency == ModelResidency.resident &&
                model.heldBy.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Held by ${model.heldBy}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            _body(context, state),
            if (_showBench) ...[const SizedBox(height: 8), _benchBody(context)],
          ],
        ),
      ),
    );
  }

  bool get _showBench {
    if (onBenchmark == null) return false;
    if (model.residency == ModelResidency.available) return false;
    final state = downloadState;
    return state == null || state is ModelDownloadIdle;
  }

  Widget _benchBody(BuildContext context) {
    final theme = Theme.of(context);
    final bench = benchState;
    final running = bench?.phase == _BenchPhase.running;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          key: Key('model_bench_${model.id}'),
          onPressed: running ? null : onBenchmark,
          icon: const Icon(Icons.speed_outlined, size: 18),
          label: const Text('Run bench'),
        ),
        if (running) ...[
          const SizedBox(height: 8),
          const Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Measuring…'),
            ],
          ),
        ],
        if (bench?.phase == _BenchPhase.measured && bench?.bench != null) ...[
          const SizedBox(height: 8),
          Text(
            '${bench!.bench!.tokensPerSecond.toStringAsFixed(1)} tok/s · '
            '${bench.bench!.firstTokenMs} ms to first token',
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (bench?.phase == _BenchPhase.failed) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              'Bench unavailable: ${bench!.reason}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: MindPalette.alarm,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _body(BuildContext context, ModelDownloadState? state) {
    final theme = Theme.of(context);

    return switch (state) {
      null || ModelDownloadIdle()
          when model.residency == ModelResidency.available =>
        FilledButton.icon(
          onPressed: onDownload,
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Download'),
        ),
      null || ModelDownloadIdle()
          when model.residency == ModelResidency.resident =>
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onLoad != null)
              OutlinedButton.icon(
                key: Key('model_load_${model.id}'),
                onPressed: onLoad,
                icon: const Icon(Icons.memory_outlined, size: 18),
                label: const Text('Load'),
              ),
            OutlinedButton.icon(
              onPressed: onUnload,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Unload'),
            ),
          ],
        ),
      null || ModelDownloadIdle() => OutlinedButton.icon(
        onPressed: onUnload,
        icon: const Icon(Icons.delete_outline, size: 18),
        label: const Text('Unload'),
      ),
      ModelDownloadCheckingStorage() => const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Checking storage…'),
        ],
      ),
      ModelDownloadInsufficientStorage(:final shortfallBytes) => Semantics(
        liveRegion: true,
        child: Text(
          'Not enough storage. Free up ${formatBytes(shortfallBytes)} to download this model.',
          style: theme.textTheme.bodySmall?.copyWith(color: MindPalette.alarm),
        ),
      ),
      ModelDownloadPausedForMetered(:final received, :final total) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: total > 0 ? received / total : null),
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(
              'Paused — mobile data (${formatBytesOf(received, total)})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onDownloadAnyway,
            child: const Text('Download anyway'),
          ),
        ],
      ),
      ModelDownloadInProgress(:final received, :final total) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: total > 0 ? received / total : null),
          const SizedBox(height: 4),
          Text(
            formatBytesOf(received, total),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      ModelDownloadStalled(:final received, :final total) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: total > 0 ? received / total : null),
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(
              'Download stalled (${formatBytesOf(received, total)})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: MindPalette.alarm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onDownload,
            child: Text(received > 0 ? 'Resume download' : 'Try again'),
          ),
        ],
      ),
      ModelDownloadCompleted() => Text(
        'Download complete',
        style: theme.textTheme.bodySmall,
      ),
      ModelDownloadFailed(:final reason) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              'Download failed: $reason',
              style: theme.textTheme.bodySmall?.copyWith(
                color: MindPalette.alarm,
              ),
            ),
          ),
          TextButton(onPressed: onDownload, child: const Text('Try again')),
        ],
      ),
    };
  }
}

class _ResidencyBadge extends StatelessWidget {
  const _ResidencyBadge({required this.model});

  final MindModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (model.residency) {
      ModelResidency.loaded => MindPalette.local,
      ModelResidency.resident => theme.colorScheme.tertiary,
      ModelResidency.available => theme.colorScheme.onSurfaceVariant,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          ModelDownloadRow._residencyLabels[model.residency]!,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

enum _BenchPhase { running, measured, failed }

class _BenchRowState {
  const _BenchRowState.running()
    : phase = _BenchPhase.running,
      bench = null,
      reason = null;

  const _BenchRowState.measured(this.bench)
    : phase = _BenchPhase.measured,
      reason = null;

  const _BenchRowState.failed(this.reason)
    : phase = _BenchPhase.failed,
      bench = null;

  final _BenchPhase phase;
  final ModelBench? bench;
  final String? reason;
}
