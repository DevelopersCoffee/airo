import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ai/core_ai.dart';

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
    return Scaffold(
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
        padding: const EdgeInsets.all(16),
        children: [
          // Header card with main info
          _buildHeaderCard(context),
          const SizedBox(height: 16),

          // Specs section
          _buildSection(
            context,
            title: 'Specifications',
            children: [
              _buildInfoRow('Family', model.family.displayName),
              _buildInfoRow('Quantization', model.quantization.displayName),
              _buildInfoRow('Size', model.fileSizeDisplay),
              if (model.parameterCountDisplay != null)
                _buildInfoRow('Parameters', model.parameterCountDisplay!),
              _buildInfoRow('Context Length', '${model.contextLength} tokens'),
            ],
          ),
          const SizedBox(height: 16),

          // Capabilities section
          _buildSection(
            context,
            title: 'Capabilities',
            children: [
              _buildCapabilityRow('Vision/Image Input', model.supportsVision),
              _buildCapabilityRow(
                'Function Calling',
                model.supportsFunctionCalling,
              ),
              _buildInfoRow(
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
                'Minimum RAM',
                _formatBytes(model.estimatedMinMemoryBytes),
              ),
              _buildInfoRow(
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
                  _buildInfoRow('Author', model.author!),
                if (model.version != null)
                  _buildInfoRow('Version', model.version!),
                if (model.license != null)
                  _buildInfoRow('License', model.license!),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCapabilityRow(String label, bool supported) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Icon(
            supported ? Icons.check_circle : Icons.cancel,
            color: supported ? Colors.green : Colors.grey,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeDownloads = ref.watch(activeDownloadsProvider);
    final downloadProgress = activeDownloads[model.id];
    final isDownloading = downloadProgress?.isInProgress ?? false;

    if (model.isDownloaded) {
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

    return FilledButton.icon(
      onPressed: isDownloading ? null : () => _downloadModel(context, ref),
      icon: Icon(isDownloading ? Icons.downloading : Icons.download),
      label: Text(
        isDownloading
            ? 'Downloading ${downloadProgress?.progressPercent ?? 0}%'
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
