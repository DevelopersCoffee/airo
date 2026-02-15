import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/group.dart';
import '../../application/providers/group_providers.dart';

/// Groups List Screen
///
/// Screen for viewing all expense-sharing groups:
/// - List of groups with balances
/// - Create new group
/// - Join existing group via invite code
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/UI_WIREFRAMES.md (Screen 5)
class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(allGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              // TODO: Scan invite QR code
            },
            tooltip: 'Scan QR Code',
          ),
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: () => _showJoinGroupDialog(context),
            tooltip: 'Join with Code',
          ),
        ],
      ),
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
            return const _EmptyGroupsView();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              return _GroupCard(group: groups[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to create group screen
        },
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
      ),
    );
  }

  void _showJoinGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Group'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Invite Code',
            hintText: 'Enter the group invite code',
          ),
          onSubmitted: (code) {
            // TODO: Join group with code
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // TODO: Join group
              Navigator.pop(context);
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroupsView extends StatelessWidget {
  const _EmptyGroupsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 24),
            Text(
              'No groups yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a group to split expenses with friends, family, or roommates.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                // TODO: Navigate to create group
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Group'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Join group with code
              },
              icon: const Icon(Icons.link),
              label: const Text('Join with Code'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to group detail
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Group Icon
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: group.iconUrl != null
                    ? ClipOval(
                        child: Image.network(group.iconUrl!, fit: BoxFit.cover),
                      )
                    : Text(
                        group.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 24),
                      ),
              ),
              const SizedBox(width: 16),

              // Group Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.memberCount} members',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Balance (placeholder)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹0',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.green,
                        ),
                  ),
                  Text(
                    'you are owed',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),

              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

