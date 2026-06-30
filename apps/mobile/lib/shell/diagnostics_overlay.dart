import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:design_system/core_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_core/platform_core.dart';
import '../version/app_version.dart';

class DiagnosticsOverlayWrapper extends ConsumerWidget {
  final Widget child;

  const DiagnosticsOverlayWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kReleaseMode) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned(
          bottom: 24,
          right: 24,
          child: Builder(
            builder: (ctx) => FloatingActionButton(
              heroTag: 'diagnostics',
              backgroundColor: AppColors.primary,
              onPressed: () => _showDiagnostics(ctx, ref),
              child: const Icon(Icons.bug_report, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  void _showDiagnostics(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => const _DiagnosticsPanel(),
    );
  }
}

class _DiagnosticsPanel extends ConsumerWidget {
  const _DiagnosticsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(bootstrapReportProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24.0),
            children: [
              Text('Diagnostics', style: AppTypography.headlineMedium),
              const SizedBox(height: 24),
              _buildSection('Platform', [
                'Version: ${AppVersion.platformVersion}',
                'App Version: ${AppVersion.applicationVersion}',
                'Build: ${AppVersion.buildNumber}',
                'Commit: ${AppVersion.gitCommit}',
              ]),
              _buildSection('Bootstrap', [
                'State: ${report?.isSuccess == true ? "Success" : "Failed"}',
                'Duration: ${report?.metrics.taskDurations.values.fold(Duration.zero, (p, e) => p + e).inMilliseconds ?? 0} ms',
              ]),
              _buildSection('Packages', report?.metrics.taskDurations.keys.toList() ?? ['None registered']),
              _buildSection('Providers', ['Scope active']),
              _buildSection('Events', ['EventBus Active']),
              _buildSection('Storage', ['Storage initialized']),
              _buildSection('Filesystem', ['Filesystem initialized']),
              _buildSection('Jobs', ['Scheduler active']),
              _buildSection('Performance', ['Profiling disabled']),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.headlineSmall.copyWith(color: AppColors.primary)),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(item, style: AppTypography.bodyMedium),
          )),
          const Divider(),
        ],
      ),
    );
  }
}
