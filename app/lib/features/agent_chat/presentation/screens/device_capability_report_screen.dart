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
                    '${recommendation.estimatedMemoryMb.toStringAsFixed(0)} MB estimated runtime memory',
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
}

class DeviceCapabilityReportLoaderScreen extends StatelessWidget {
  const DeviceCapabilityReportLoaderScreen({
    super.key,
    this.models = const <OfflineModelInfo>[],
  });

  final Iterable<OfflineModelInfo> models;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DeviceCapabilityReport>(
      future: DeviceCapabilityReport.collect(models: models),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Device Capability Report')),
            body: Center(
              child: Text('Could not read device facts: ${snapshot.error}'),
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
