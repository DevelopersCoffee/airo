import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ai/core_ai.dart';
import 'package:core_ui/core_ui.dart';

import '../../application/ai_model_management.dart';
import '../../../../core/ai/model_learn_more_launcher.dart';
import '../widgets/credibility_badge.dart';

/// Detail screen for viewing and managing a single AI model.
///
/// Shows comprehensive model information, compatibility details,
/// and provides download/delete actions.
class ModelDetailScreen extends ConsumerWidget {
  const ModelDetailScreen({
    super.key,
    required this.model,
    this.launchUrlCallback,
  });

  final OfflineModelInfo model;
  final LaunchModelUrl? launchUrlCallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AiroResponsiveScaffold(
      appBar: AppBar(
        title: Text(model.name),
        actions: [
          if (model.learnMoreUri != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Learn more',
              onPressed: () => _openLearnMore(context),
            ),
        ],
      ),
      body: ListView(
        children: [
          // Header card with main info
          _buildHeaderCard(context),
          const SizedBox(height: 16),

          // Specs section
          _buildSection(
            context,
            title: 'Specifications',
            children: [
              _buildInfoRow(context, 'Family', model.family.displayName),
              _buildInfoRow(
                context,
                'Quantization',
                model.quantization.displayName,
              ),
              _buildInfoRow(context, 'Size', model.fileSizeDisplay),
              if (model.parameterCountDisplay != null)
                _buildInfoRow(
                  context,
                  'Parameters',
                  model.parameterCountDisplay!,
                ),
              _buildInfoRow(
                context,
                'Context Length',
                '${model.contextLength} tokens',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Capabilities section
          _buildSection(
            context,
            title: 'Capabilities',
            children: [
              _buildCapabilityRow(
                context,
                'Vision/Image Input',
                model.supportsVision,
              ),
              _buildCapabilityRow(
                context,
                'Function Calling',
                model.supportsFunctionCalling,
              ),
              _buildInfoRow(
                context,
                'Languages',
                model.languages.map((l) => l.toUpperCase()).join(', '),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Memory requirements
          _buildSection(
            context,
            title: 'Memory Requirements',
            children: [
              _buildInfoRow(
                context,
                'Minimum RAM',
                _formatBytes(model.estimatedMinMemoryBytes),
              ),
              _buildInfoRow(
                context,
                'Recommended RAM',
                _formatBytes(model.estimatedRecommendedMemoryBytes),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Metadata section
          if (model.author != null ||
              model.version != null ||
              model.license != null)
            _buildSection(
              context,
              title: 'Metadata',
              children: [
                if (model.author != null)
                  _buildInfoRow(context, 'Author', model.author!),
                if (model.version != null)
                  _buildInfoRow(context, 'Version', model.version!),
                if (model.license != null)
                  _buildInfoRow(context, 'License', model.license!),
              ],
            ),

          const SizedBox(height: 24),

          // Action button
          _buildActionButton(context, ref),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(model.name, style: theme.textTheme.headlineSmall),
                ),
                CredibilityBadgeWithInfo(
                  credibility: model.credibility,
                  size: CredibilityBadgeSize.large,
                ),
              ],
            ),
            if (model.description != null) ...[
              const SizedBox(height: 12),
              Text(
                model.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (model.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: model.tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                        labelStyle: theme.textTheme.labelSmall,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final mediaQuery = MediaQuery.of(context);
    final isTextLarge = mediaQuery.textScaler.scale(10) > 12.5;

    final labelText = Text(label);
    final valueText = Text(
      value,
      style: const TextStyle(fontWeight: FontWeight.w500),
      textAlign: isTextLarge ? TextAlign.start : TextAlign.end,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: isTextLarge
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, const SizedBox(height: 2), valueText],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: labelText),
                const SizedBox(width: 8),
                valueText,
              ],
            ),
    );
  }

  Widget _buildCapabilityRow(
    BuildContext context,
    String label,
    bool supported,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final isTextLarge = mediaQuery.textScaler.scale(10) > 12.5;

    final labelText = Text(label);
    final statusIcon = Icon(
      supported ? Icons.check_circle : Icons.cancel,
      color: supported ? Colors.green : Colors.grey,
      size: 20,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: isTextLarge
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, const SizedBox(height: 4), statusIcon],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: labelText),
                const SizedBox(width: 8),
                statusIcon,
              ],
            ),
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeDownloads = ref.watch(activeDownloadsProvider);
    final downloadProgress = activeDownloads[model.id];
    final isDownloading = downloadProgress?.isActive ?? false;
    final mediaQuery = MediaQuery.of(context);
    final isTextLarge = mediaQuery.textScaler.scale(10) > 12.5;

    if (model.isDownloaded) {
      if (isTextLarge) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () => _setActive(context, ref),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Set as Active Model'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _deleteModel(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Model'),
            ),
          ],
        );
      } else {
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _setActive(context, ref),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Set as Active Model'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => _deleteModel(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Icon(Icons.delete_outline),
            ),
          ],
        );
      }
    }

    return FilledButton.icon(
      onPressed: isDownloading ? null : () => _downloadModel(context, ref),
      icon: Icon(isDownloading ? Icons.downloading : Icons.download),
      label: Text(
        isDownloading
            ? '${downloadProgress?.statusDisplay ?? 'Downloading'} ${downloadProgress?.progressPercent ?? 0}%'
            : 'Download (${model.fileSizeDisplay})',
      ),
    );
  }

  String _formatBytes(int bytes) {
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.toStringAsFixed(1)} GB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }

  Future<void> _openLearnMore(BuildContext context) {
    return launchModelLearnMore(
      context,
      model,
      launchUrlCallback: launchUrlCallback,
    );
  }

  Future<void> _setActive(BuildContext context, WidgetRef ref) async {
    await activateOfflineModel(ref, model);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${model.name} is now active')));
    Navigator.pop(context);
  }

  Future<void> _downloadModel(BuildContext context, WidgetRef ref) async {
    ref.read(activeDownloadsProvider.notifier).startDownload(model);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting download of ${model.name}...')),
    );
  }

  Future<void> _deleteModel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text(
          'Delete ${model.name}? This will free up ${model.fileSizeDisplay}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final downloadService = ref.read(modelDownloadServiceProvider);
        final deleted = await downloadService.deleteModel(model.id);

        if (deleted) {
          ref.read(modelRegistryProvider).markAsRemoved(model.id);
          await clearOfflineModelSelections(ref, model);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${model.name} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${model.name} file not found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
