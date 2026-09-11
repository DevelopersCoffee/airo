import 'package:core_ui/core_ui.dart';
import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/anya_providers.dart';

class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(anyaSessionProvider);
    if (session.programs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Programs')),
        body: const EmptyStateWidget(
          title: 'No imported programs',
          message:
              'Each PDF becomes its own program. Phase merging comes later.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Programs')),
      body: ListView(
        padding: AiroSpacing.paddingMd,
        children: [
          for (final program in session.programs)
            AppCard(
              onTap: () => ref
                  .read(anyaSessionProvider.notifier)
                  .activateProgram(program.id),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(program.title),
                subtitle: Text(
                  '${program.source == ProgramSource.imported ? 'Imported' : 'Generated'} · ${program.allDays.length} days',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (session.snapshot.activeProgramId == program.id)
                      const Icon(Icons.check),
                    IconButton(
                      tooltip: 'Delete program',
                      onPressed: () => ref
                          .read(anyaSessionProvider.notifier)
                          .deleteProgram(program.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
