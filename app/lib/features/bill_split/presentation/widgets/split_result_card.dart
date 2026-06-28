import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../application/providers/bill_split_providers.dart';
import '../../domain/models/bill_split_models.dart';
import '../../domain/models/split_result.dart';

/// Widget displaying split results with share options
class SplitResultCard extends ConsumerWidget {
  const SplitResultCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final splitResult = ref.watch(currentSplitResultProvider);

    if (splitResult == null) {
      return const Center(child: Text('No split calculated'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bill Split Complete!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      splitResult.splitType.displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Bill summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        splitResult.bill.vendor ?? 'Bill',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        splitResult.bill.formattedTotal,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Split among ${splitResult.participantCount} people',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Individual splits
          Text(
            'Individual Shares',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          ...splitResult.splits.map((split) {
            return _SplitTile(split: split, splitResult: splitResult);
          }),

          const SizedBox(height: 24),

          // Share all button
          OutlinedButton.icon(
            onPressed: () => _shareAll(context, splitResult),
            icon: const Icon(Icons.share),
            label: const Text('Share Summary with All'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 12),

          // Copy summary button
          TextButton.icon(
            onPressed: () => _copySummary(context, splitResult),
            icon: const Icon(Icons.copy),
            label: const Text('Copy Summary'),
          ),
        ],
      ),
    );
  }

  void _shareAll(BuildContext context, SplitResult result) {
    final message = result.generateSummaryMessage();
    SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: 'Bill Split - ${result.bill.vendor ?? ""}',
      ),
    );
  }

  void _copySummary(BuildContext context, SplitResult result) {
    final message = result.generateSummaryMessage();
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Summary copied to clipboard')),
    );
  }
}

class _SplitTile extends StatelessWidget {
  final ParticipantSplit split;
  final SplitResult splitResult;

  const _SplitTile({required this.split, required this.splitResult});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            split.participant.initials,
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
        title: Text(split.participant.name),
        subtitle: Text(split.participant.phone ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              split.formattedAmount,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => _shareToPerson(context),
              tooltip: 'Share',
            ),
          ],
        ),
      ),
    );
  }

  void _shareToPerson(BuildContext context) {
    final message = splitResult.generateShareMessage(split);
    SharePlus.instance.share(
      ShareParams(text: message, subject: 'Your share of the bill'),
    );
  }
}
