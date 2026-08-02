import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Loads live compatibility facts without blocking navigation to the health
/// center. Platform probes can be slow or unavailable after an OS update.
class ModelHealthCenterLoaderScreen extends StatelessWidget {
  const ModelHealthCenterLoaderScreen({
    super.key,
    required this.model,
    required this.compatibilityFuture,
    this.artifactPresentFuture,
    this.onAction,
  });

  final OfflineModelInfo model;
  final Future<ModelCompatibilityResult> compatibilityFuture;
  final Future<bool>? artifactPresentFuture;
  final ValueChanged<ModelHealthAction>? onAction;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object?>>(
      future: Future.wait<Object?>([
        compatibilityFuture,
        artifactPresentFuture ?? Future<bool>.value(model.isDownloaded),
      ]),
      builder: (context, snapshot) {
        final compatibility = snapshot.data?[0] as ModelCompatibilityResult?;
        final artifactPresent = snapshot.data?[1] as bool?;
        if (compatibility != null && artifactPresent != null) {
          return ModelHealthCenterScreen(
            report: ModelHealthReport.fromFacts(
              model: model,
              artifactPresent: artifactPresent,
              compatibility: compatibility,
            ),
            onAction: onAction,
          );
        }
        if (snapshot.hasError) {
          return ModelHealthCenterScreen(
            report: ModelHealthReport.fromFacts(model: model),
            onAction: onAction,
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Runtime Health Center')),
          body: const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Reading device facts',
            ),
          ),
        );
      },
    );
  }
}

/// Explains model readiness in user-facing language without exposing runtime
/// exception strings or platform-specific implementation details.
class ModelHealthCenterScreen extends StatelessWidget {
  const ModelHealthCenterScreen({
    super.key,
    required this.report,
    this.onAction,
  });

  final ModelHealthReport report;
  final ValueChanged<ModelHealthAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(theme, report.status);
    return Scaffold(
      appBar: AppBar(title: const Text('Runtime Health Center')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Semantics(
            container: true,
            label:
                '${report.modelName} runtime status: ${_statusLabel(report.status)}',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.14),
                      foregroundColor: color,
                      child: Icon(_statusIcon(report.status)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.modelName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _statusLabel(report.status),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_whyTitle(report), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(report.explanation),
                  if (report.availableMemoryMb != null &&
                      report.requiredMemoryMb != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Memory: ${report.availableMemoryMb!.toStringAsFixed(0)} MB available · ${report.requiredMemoryMb!.toStringAsFixed(0)} MB estimated peak',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (report.runtime != null || report.accelerator != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Execution: ${report.runtime?.name ?? 'not selected'} · ${report.accelerator?.name ?? 'automatic accelerator'}${report.contextTokens == null ? '' : ' · ${report.contextTokens} token context'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: report.toMarkdown()),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Runtime diagnostics copied.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy diagnostics'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Readiness timeline', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (var index = 0; index < report.stages.length; index++)
                  _StageTile(
                    result: report.stages[index],
                    isLast: index == report.stages.length - 1,
                  ),
              ],
            ),
          ),
          if (report.trace != null && report.trace!.entries.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Runtime trace', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final entry in report.trace!.entries)
                    Semantics(
                      container: true,
                      label:
                          'Runtime trace step ${entry.sequence}: ${_traceLabel(entry.event)}, ${entry.elapsedMs} milliseconds.',
                      child: ExcludeSemantics(
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 12,
                            child: Text('${entry.sequence}'),
                          ),
                          title: Text(_traceLabel(entry.event)),
                          trailing: Text('${entry.elapsedMs} ms'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (report.actions.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Recommended next steps', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final action in report.actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: onAction == null ? null : () => onAction!(action),
                  icon: Icon(_actionIcon(action)),
                  label: Text(_actionLabel(action)),
                ),
              ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Airo keeps prompts and model inference on this device when a local runtime is selected.',
          ),
        ],
      ),
    );
  }

  static Color _statusColor(ThemeData theme, ModelHealthReportStatus status) {
    return switch (status) {
      ModelHealthReportStatus.ready ||
      ModelHealthReportStatus.running => Colors.green.shade700,
      ModelHealthReportStatus.recoverable => theme.colorScheme.error,
      ModelHealthReportStatus.preparing => theme.colorScheme.primary,
      ModelHealthReportStatus.unknown => theme.colorScheme.onSurfaceVariant,
    };
  }

  static IconData _statusIcon(ModelHealthReportStatus status) =>
      switch (status) {
        ModelHealthReportStatus.ready => Icons.check_circle_outline,
        ModelHealthReportStatus.running => Icons.bolt,
        ModelHealthReportStatus.recoverable => Icons.warning_amber_outlined,
        ModelHealthReportStatus.preparing => Icons.hourglass_top,
        ModelHealthReportStatus.unknown => Icons.help_outline,
      };

  static String _statusLabel(ModelHealthReportStatus status) =>
      switch (status) {
        ModelHealthReportStatus.ready => 'Ready for inference',
        ModelHealthReportStatus.running => 'Running on device',
        ModelHealthReportStatus.recoverable => 'Needs attention',
        ModelHealthReportStatus.preparing => 'Preparing model',
        ModelHealthReportStatus.unknown => 'Health information pending',
      };

  static String _whyTitle(ModelHealthReport report) => switch (report.status) {
    ModelHealthReportStatus.ready ||
    ModelHealthReportStatus.running => 'Why this model can run',
    ModelHealthReportStatus.preparing ||
    ModelHealthReportStatus.recoverable ||
    ModelHealthReportStatus.unknown => 'Why can’t this model load?',
  };

  static IconData _actionIcon(ModelHealthAction action) => switch (action) {
    ModelHealthAction.retry => Icons.refresh,
    ModelHealthAction.resumeDownload => Icons.download,
    ModelHealthAction.repair => Icons.build_outlined,
    ModelHealthAction.reduceContext => Icons.compress,
    ModelHealthAction.chooseAlternative => Icons.swap_horiz,
  };

  static String _actionLabel(ModelHealthAction action) => switch (action) {
    ModelHealthAction.retry => 'Retry runtime',
    ModelHealthAction.resumeDownload => 'Resume download',
    ModelHealthAction.repair => 'Repair model',
    ModelHealthAction.reduceContext => 'Retry with reduced context',
    ModelHealthAction.chooseAlternative => 'Choose another installed model',
  };

  static String _traceLabel(ExecutionTraceEvent event) => switch (event) {
    ExecutionTraceEvent.initializing => 'Initializing runtime',
    ExecutionTraceEvent.ready => 'Runtime ready',
    ExecutionTraceEvent.generationStarted => 'Generation started',
    ExecutionTraceEvent.firstToken => 'First token received',
    ExecutionTraceEvent.streaming => 'Streaming tokens',
    ExecutionTraceEvent.generationFinished => 'Generation finished',
    ExecutionTraceEvent.generationFailed => 'Generation failed',
    ExecutionTraceEvent.shuttingDown => 'Shutting down',
    ExecutionTraceEvent.stopped => 'Runtime stopped',
  };
}

class _StageTile extends StatelessWidget {
  const _StageTile({required this.result, required this.isLast});

  final ModelHealthStageResult result;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (result.status) {
      ModelHealthStageStatus.passed => (Icons.check_circle, Colors.green),
      ModelHealthStageStatus.blocked || ModelHealthStageStatus.failed => (
        Icons.error_outline,
        theme.colorScheme.error,
      ),
      ModelHealthStageStatus.pending => (Icons.hourglass_empty, Colors.orange),
      ModelHealthStageStatus.unknown => (
        Icons.radio_button_unchecked,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    return Semantics(
      container: true,
      label:
          '${_stageLabel(result.stage)}: ${_stageStatusLabel(result.status)}. ${result.detail}',
      child: ExcludeSemantics(
        child: ListTile(
          leading: Column(
            children: [
              Icon(icon, color: color),
              if (!isLast)
                Expanded(
                  child: VerticalDivider(color: color.withValues(alpha: 0.35)),
                ),
            ],
          ),
          title: Text(_stageLabel(result.stage)),
          subtitle: Text(result.detail),
        ),
      ),
    );
  }

  static String _stageLabel(ModelHealthStage stage) => switch (stage) {
    ModelHealthStage.downloaded => 'Downloaded',
    ModelHealthStage.verified => 'Verified',
    ModelHealthStage.compatible => 'Compatible',
    ModelHealthStage.runtimeReady => 'Runtime ready',
    ModelHealthStage.warmedUp => 'Warmed up',
    ModelHealthStage.running => 'Running',
  };

  static String _stageStatusLabel(ModelHealthStageStatus status) =>
      switch (status) {
        ModelHealthStageStatus.passed => 'complete',
        ModelHealthStageStatus.blocked => 'blocked',
        ModelHealthStageStatus.failed => 'failed',
        ModelHealthStageStatus.pending => 'in progress',
        ModelHealthStageStatus.unknown => 'not checked yet',
      };
}
