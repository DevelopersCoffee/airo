import 'package:core_ai/core_ai.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/settings/application/ai_model_management.dart';
import '../../features/settings/presentation/screens/ai_models_screen.dart';
import '../../features/settings/presentation/screens/intelligent_model_manager_screen.dart';

/// Standalone Mind shell: model hub styled after on-device AI gallery apps.
///
/// Surfaces download, activation, and warmup status in one place instead of
/// burying them under Profile → AI preferences (which the super app reaches
/// through Settings).
class MindModelsScreen extends ConsumerWidget {
  const MindModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedCatalog = ref.watch(selectedModelProvider);
    final assistantId = ref.watch(selectedAssistantModelIdProvider);
    final readiness = ref.watch(assistantRuntimeReadinessProvider);
    final activeDownloads = ref.watch(activeDownloadsProvider);

    return AiroResponsiveScaffold(
      appBar: AppBar(title: const Text('On-device models'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Browse curated packages, litert-community releases, and public GGUF '
            'models from Hugging Face. Download one, warm it, then chat — '
            'nothing runs until you pick a model.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _ActiveModelCard(
            catalogModel: selectedCatalog,
            assistantRuntimeId: assistantId,
            readiness: readiness,
          ),
          if (readiness.phase != AssistantRuntimeReadinessPhase.ready &&
              readiness.phase != AssistantRuntimeReadinessPhase.idle &&
              readiness.phase != AssistantRuntimeReadinessPhase.blocked) ...[
            const SizedBox(height: 12),
            _ProgressCard(readiness: readiness),
          ],
          if (activeDownloads.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DownloadsCard(downloads: activeDownloads),
          ],
          const SizedBox(height: 20),
          _ActionTile(
            icon: Icons.cloud_download_outlined,
            title: 'Browse Hugging Face catalog',
            subtitle:
                'Curated, litert-community, and public GGUF — cached for offline browse',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AIModelsScreen()),
            ),
          ),
          _ActionTile(
            icon: Icons.memory_outlined,
            title: 'Model manager',
            subtitle: 'Activate, warm, benchmark, and free storage',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const IntelligentModelManagerScreen(),
              ),
            ),
          ),
          _ActionTile(
            icon: Icons.psychology_outlined,
            title: 'Assistant projects',
            subtitle: 'Pick which runtime powers chat, docs, and skills',
            onTap: () => context.go('${AssistantRouteNames.assistant}/models'),
          ),
        ],
      ),
    );
  }
}

class _ActiveModelCard extends StatelessWidget {
  const _ActiveModelCard({
    required this.catalogModel,
    required this.assistantRuntimeId,
    required this.readiness,
  });

  final OfflineModelInfo? catalogModel;
  final String? assistantRuntimeId;
  final AssistantRuntimeReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name =
        catalogModel?.name ?? assistantRuntimeId ?? 'No model selected';
    final statusLabel = switch (readiness.phase) {
      AssistantRuntimeReadinessPhase.idle => 'Choose a model to begin',
      AssistantRuntimeReadinessPhase.loading => 'Loading weights…',
      AssistantRuntimeReadinessPhase.warming => 'Warming up…',
      AssistantRuntimeReadinessPhase.ready => 'Ready to chat',
      AssistantRuntimeReadinessPhase.blocked => 'Setup required',
      AssistantRuntimeReadinessPhase.error => 'Something went wrong',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active model', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(statusLabel, style: theme.textTheme.bodyMedium),
            if (readiness.detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                readiness.detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.readiness});

  final AssistantRuntimeReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (readiness.progress * 100).clamp(0, 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    readiness.label,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text('$percent%', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: readiness.progress.clamp(0.0, 1.0)),
          ],
        ),
      ),
    );
  }
}

class _DownloadsCard extends StatelessWidget {
  const _DownloadsCard({required this.downloads});

  final Map<String, ModelDownloadProgress> downloads;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Downloads', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            for (final progress in downloads.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(progress.modelId)),
                        Text('${progress.progressPercent}%'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: progress.progress),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
