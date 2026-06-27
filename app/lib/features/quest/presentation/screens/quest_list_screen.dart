import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../quest/application/providers/quest_provider.dart';
import '../../../quest/domain/models/quest_models.dart';

/// Quest list screen - progress and rewards hub for user quests.
class QuestListScreen extends ConsumerWidget {
  const QuestListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(questListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quest'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/quest/new'),
          ),
        ],
      ),
      body: questsAsync.when(
        data: (quests) {
          final summary = _QuestSummary.fromQuests(quests);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _QuestProgressHero(summary: summary),
              const SizedBox(height: 16),
              _QuestActiveSection(summary: summary),
              const SizedBox(height: 16),
              _QuestRewardsSection(summary: summary),
              const SizedBox(height: 16),
              _QuestProgressSection(summary: summary),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'All Quests',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Text(
                    '${quests.length} total',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (quests.isEmpty)
                _EmptyQuestState(onCreateQuest: () => context.go('/quest/new'))
              else
                ...quests.map((quest) => _QuestCard(quest: quest)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                'Error loading quests',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.refresh(questListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/quest/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Quest'),
      ),
    );
  }
}

class _QuestProgressHero extends StatelessWidget {
  const _QuestProgressHero({required this.summary});

  final _QuestSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quest Progress',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: 0.72,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${summary.completionPercent}% complete',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: summary.progressValue,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricChip(
                icon: Icons.local_fire_department,
                label: '${summary.streakDays}-day streak',
              ),
              _MetricChip(
                icon: Icons.task_alt,
                label: '${summary.activeCount} active quests',
              ),
              _MetricChip(
                icon: Icons.workspace_premium,
                label: '${summary.rewardCoins} coins earned',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestActiveSection extends StatelessWidget {
  const _QuestActiveSection({required this.summary});

  final _QuestSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Quests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStatTile(
                    title: 'Daily',
                    value: summary.dailyCount.toString(),
                    subtitle: 'Short-cycle focus',
                    icon: Icons.today,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStatTile(
                    title: 'Weekly',
                    value: summary.weeklyCount.toString(),
                    subtitle: 'Longer-running work',
                    icon: Icons.date_range,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestRewardsSection extends StatelessWidget {
  const _QuestRewardsSection({required this.summary});

  final _QuestSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rewards', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStatTile(
                    title: 'Coins',
                    value: summary.rewardCoins.toString(),
                    subtitle: 'Progress rewards',
                    icon: Icons.monetization_on,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStatTile(
                    title: 'Unlocks',
                    value: summary.unlockCount.toString(),
                    subtitle: 'Milestones reached',
                    icon: Icons.lock_open,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestProgressSection extends StatelessWidget {
  const _QuestProgressSection({required this.summary});

  final _QuestSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Tracker',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _ProgressRow(
              label: 'Completion',
              value: '${summary.completionPercent}%',
              progress: summary.progressValue,
            ),
            const SizedBox(height: 12),
            _ProgressRow(
              label: 'Streak',
              value:
                  '${summary.streakDays} day${summary.streakDays == 1 ? '' : 's'}',
              progress: summary.streakValue,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _statusColor(quest.status).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _statusIcon(quest.status),
            color: _statusColor(quest.status),
          ),
        ),
        title: Text(
          quest.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (quest.description != null && quest.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                quest.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  '${quest.files.length} file(s)',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                Text(
                  '${quest.messages.length} message(s)',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                Text(
                  '${quest.reminders.length} reminder(s)',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(quest.updatedAt ?? quest.createdAt),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: () => context.go('/quest/${quest.id}'),
      ),
    );
  }
}

class _EmptyQuestState extends StatelessWidget {
  const _EmptyQuestState({required this.onCreateQuest});

  final VoidCallback onCreateQuest;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.explore_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No Quests Yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new quest to start building streaks, rewards, and progress.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateQuest,
              icon: const Icon(Icons.add),
              label: const Text('Create Quest'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatTile extends StatelessWidget {
  const _MiniStatTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(999),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
      ),
    );
  }
}

class _QuestSummary {
  const _QuestSummary({
    required this.totalCount,
    required this.activeCount,
    required this.completedCount,
    required this.dailyCount,
    required this.weeklyCount,
    required this.rewardCoins,
    required this.unlockCount,
    required this.streakDays,
  });

  final int totalCount;
  final int activeCount;
  final int completedCount;
  final int dailyCount;
  final int weeklyCount;
  final int rewardCoins;
  final int unlockCount;
  final int streakDays;

  factory _QuestSummary.fromQuests(List<Quest> quests) {
    final activeQuests = quests
        .where((quest) => quest.status == 'active')
        .toList();
    final completedQuests = quests
        .where((quest) => quest.status == 'completed')
        .toList();
    final daily = activeQuests.where(_isDailyQuest).length;
    final weekly = activeQuests.length - daily;
    final rewardCoins =
        (completedQuests.length * 50) +
        (activeQuests.length * 10) +
        quests.fold<int>(0, (sum, quest) => sum + quest.reminders.length * 5);
    final unlockCount = [
      if (quests.isNotEmpty) 'first-quest',
      if (completedQuests.isNotEmpty) 'first-complete',
      if (quests.length >= 3) 'quest-keeper',
      if (quests.any((quest) => quest.files.isNotEmpty)) 'artifact-collector',
    ].length;

    return _QuestSummary(
      totalCount: quests.length,
      activeCount: activeQuests.length,
      completedCount: completedQuests.length,
      dailyCount: daily,
      weeklyCount: weekly,
      rewardCoins: rewardCoins,
      unlockCount: unlockCount,
      streakDays: _calculateStreakDays(quests),
    );
  }

  int get completionPercent {
    if (totalCount == 0) return 0;
    return ((completedCount / totalCount) * 100).round();
  }

  double get progressValue {
    if (totalCount == 0) return 0;
    return completedCount / totalCount;
  }

  double get streakValue {
    if (streakDays == 0) return 0;
    return (streakDays / 7).clamp(0, 1).toDouble();
  }

  static bool _isDailyQuest(Quest quest) {
    if (quest.reminders.any(
      (reminder) =>
          reminder.isRecurring && reminder.recurringPattern == 'daily',
    )) {
      return true;
    }

    final updated = quest.updatedAt ?? quest.createdAt;
    return DateTime.now().difference(updated).inDays <= 1;
  }

  static int _calculateStreakDays(List<Quest> quests) {
    if (quests.isEmpty) return 0;

    final activityDays =
        quests
            .map((quest) => quest.updatedAt ?? quest.createdAt)
            .map((date) => DateTime(date.year, date.month, date.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);

    while (activityDays.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inMinutes < 1) {
    return 'Just now';
  } else if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  } else if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  } else if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  } else {
    return '${date.day}/${date.month}/${date.year}';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'completed':
      return Colors.green;
    case 'archived':
      return Colors.grey;
    default:
      return Colors.blue;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'completed':
      return Icons.emoji_events;
    case 'archived':
      return Icons.archive_outlined;
    default:
      return Icons.explore;
  }
}
