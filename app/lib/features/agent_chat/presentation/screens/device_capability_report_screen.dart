import 'dart:async';

import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';

/// Shows the normalized device facts consumed by the runtime planner.
class DeviceCapabilityReportScreen extends StatelessWidget {
  const DeviceCapabilityReportScreen({super.key, required this.report});

  final DeviceCapabilityReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Device Capability Report')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.device.displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${report.device.osVersion} · SDK ${report.device.sdkVersion}',
                  ),
                  const SizedBox(height: 14),
                  Text(report.summary),
                  const SizedBox(height: 8),
                  Text(
                    'On-device AI: ${report.device.supportsOnDeviceAI ? 'available' : 'not reported'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Runtime diagnostics', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final diagnostic in report.diagnostics)
            Card(
              child: ListTile(
                leading: Icon(
                  _diagnosticIcon(diagnostic.severity),
                  color: _diagnosticColor(theme, diagnostic.severity),
                ),
                title: Text(diagnostic.title),
                subtitle: Text(diagnostic.detail),
              ),
            ),
          const SizedBox(height: 18),
          Text('Recommended models', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (report.recommendedModels.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('No model metadata loaded yet'),
                subtitle: Text('Open Model Management to refresh the catalog.'),
              ),
            )
          else
            for (final recommendation in report.recommendedModels)
              Card(
                child: ListTile(
                  leading: Icon(
                    recommendation.recommended
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_outlined,
                    color: recommendation.recommended
                        ? Colors.green.shade700
                        : theme.colorScheme.error,
                  ),
                  title: Text(recommendation.modelName),
                  subtitle: Text(
                    '${recommendation.severity.title} · '
                    '${recommendation.estimatedMemoryMb.toStringAsFixed(0)} MB estimated runtime memory'
                    '${_expectedTokensLabel(recommendation)}',
                  ),
                ),
              ),
          const SizedBox(height: 12),
          const Text(
            'These recommendations are advisory. The runtime performs a final transient-memory check immediately before loading.',
          ),
        ],
      ),
    );
  }

  static IconData _diagnosticIcon(MemorySeverity severity) {
    return switch (severity) {
      MemorySeverity.safe => Icons.check_circle_outline,
      MemorySeverity.warning => Icons.info_outline,
      MemorySeverity.critical => Icons.warning_amber_outlined,
      MemorySeverity.blocked => Icons.error_outline,
    };
  }

  static Color _diagnosticColor(ThemeData theme, MemorySeverity severity) {
    return switch (severity) {
      MemorySeverity.safe => Colors.green.shade700,
      MemorySeverity.warning => theme.colorScheme.primary,
      MemorySeverity.critical ||
      MemorySeverity.blocked => theme.colorScheme.error,
    };
  }

  static String _expectedTokensLabel(DeviceModelRecommendation recommendation) {
    final expected = recommendation.expectedTokensPerSecond;
    if (expected == null || expected <= 0) return '';
    return ' · Expected ${expected.toStringAsFixed(1)} tok/s';
  }
}

class DeviceCapabilityReportLoaderScreen extends StatefulWidget {
  const DeviceCapabilityReportLoaderScreen({
    super.key,
    this.models = const <OfflineModelInfo>[],
    this.reportFuture,
  });

  final Iterable<OfflineModelInfo> models;
  final Future<DeviceCapabilityReport>? reportFuture;

  @override
  State<DeviceCapabilityReportLoaderScreen> createState() =>
      _DeviceCapabilityReportLoaderScreenState();
}

class _DeviceCapabilityReportLoaderScreenState
    extends State<DeviceCapabilityReportLoaderScreen> {
  late Future<DeviceCapabilityReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _collectReport();
  }

  Future<DeviceCapabilityReport> _collectReport() {
    final supplied = widget.reportFuture;
    final future =
        supplied ?? DeviceCapabilityReport.collect(models: widget.models);
    return future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException(
        'Device analysis took too long. Check platform permissions and retry.',
      ),
    );
  }

  void _retry() {
    setState(() => _reportFuture = _collectReport());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DeviceCapabilityReport>(
      future: _reportFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Device Capability Report')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_outlined, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Airo could not finish device analysis. Check permissions, then try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry analysis'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final report = snapshot.data;
        if (report == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return DeviceCapabilityReportScreen(report: report);
      },
    );
  }
}
