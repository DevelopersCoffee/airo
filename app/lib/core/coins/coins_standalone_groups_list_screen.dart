import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/coins/application/providers/group_providers.dart';
import '../../features/coins/application/services/coins_invite_link_service.dart';
import '../../features/coins/application/services/coins_platform_support.dart';

/// Groups list for the standalone Airo Coin shell (no cloud upsell, no OCR).
class CoinsStandaloneGroupsListScreen extends ConsumerWidget {
  const CoinsStandaloneGroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!CoinsPlatformSupport.groupsAvailable()) {
      return const _UnsupportedGroupsView();
    }

    final groupsAsync = ref.watch(allGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Shared expenses')),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(allGroupsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return _EmptyGroupsView(
              onCreateGroup: () => _showCreateGroupDialog(context, ref),
              onJoinGroup: () => _showJoinGroupDialog(context, ref),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(group.name),
                  subtitle: Text('${group.memberCount} members'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/groups/${group.id}'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGroupDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Group name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await ref
                  .read(createGroupProvider.notifier)
                  .createGroupFromInput(
                    name: name,
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    creatorId: 'local_user',
                    creatorDisplayName: 'You',
                  );
              final created = ref.read(createGroupProvider);
              if (!context.mounted || !dialogContext.mounted) return;
              created.whenOrNull(
                data: (group) {
                  Navigator.pop(dialogContext);
                  if (group != null) {
                    context.push('/groups/${group.id}');
                  }
                },
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ).whenComplete(() {
      nameController.dispose();
      descriptionController.dispose();
    });
  }

  void _showJoinGroupDialog(BuildContext context, WidgetRef ref) {
    final codeController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join Group'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(labelText: 'Invite code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final code = const CoinsInviteLinkService().extractInviteCode(
                codeController.text,
              );
              if (code.isEmpty) return;
              final result = await ref
                  .read(groupRepositoryProvider)
                  .findByInviteCode(code);
              if (!context.mounted || !dialogContext.mounted) return;
              final group = result.data;
              if (group == null) return;
              Navigator.pop(dialogContext);
              context.push('/groups/${group.id}');
            },
            child: const Text('Join'),
          ),
        ],
      ),
    ).whenComplete(codeController.dispose);
  }
}

class _UnsupportedGroupsView extends StatelessWidget {
  const _UnsupportedGroupsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shared expenses')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Shared expenses need native storage. Use the Airo Coin Android app.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _EmptyGroupsView extends StatelessWidget {
  const _EmptyGroupsView({
    required this.onCreateGroup,
    required this.onJoinGroup,
  });

  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'No groups yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onCreateGroup,
              child: const Text('Create Group'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onJoinGroup,
              child: const Text('Join with code'),
            ),
          ],
        ),
      ),
    );
  }
}
