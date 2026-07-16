import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/locale_settings.dart';
import '../../application/providers/cloud_mode_provider.dart';
import '../../application/services/coins_platform_support.dart';
import '../../application/services/coins_invite_link_service.dart';
import '../../domain/entities/group.dart';
import '../../application/providers/group_providers.dart';
import 'group_detail_screen.dart';

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
    if (!CoinsPlatformSupport.groupsAvailable()) {
      return const _UnsupportedGroupsView();
    }

    final groupsAsync = ref.watch(allGroupsProvider);
    final cloudModeAsync = ref.watch(coinsCloudModeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _showJoinGroupDialog(context, ref),
            tooltip: 'Scan QR Code',
          ),
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: () => _showJoinGroupDialog(context, ref),
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CloudModeCard(
                stateAsync: cloudModeAsync,
                onEnableCloud: () => _enableCloudMode(context, ref),
                onUseLocal: () => ref
                    .read(coinsCloudModeControllerProvider.notifier)
                    .useLocalMode(),
              ),
              const SizedBox(height: 12),
              if (groups.isEmpty)
                _EmptyGroupsView(
                  onCreateGroup: () => _showCreateGroupDialog(context, ref),
                  onJoinGroup: () => _showJoinGroupDialog(context, ref),
                )
              else
                ...groups.map((group) => _GroupCard(group: group)),
            ],
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

  Future<bool> _enableCloudMode(BuildContext context, WidgetRef ref) async {
    final enabled = await ref
        .read(coinsCloudModeControllerProvider.notifier)
        .enableCloudMode();
    if (!context.mounted) return enabled;
    final state = ref.read(coinsCloudModeControllerProvider).value;
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state?.errorMessage ?? 'Cloud mode needs Google sign-in',
          ),
        ),
      );
    }
    return enabled;
  }

  void _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final dialog = showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('create_group_name_field'),
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Group name',
                hintText: 'Roommates, Goa trip, Office lunch',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('create_group_desc_field'),
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional',
              ),
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
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Group name is required')),
                );
                return;
              }
              final cloudState = ref
                  .read(coinsCloudModeControllerProvider)
                  .value;
              final user = cloudState?.user;
              final creatorId =
                  cloudState?.isCloudMode == true && user?.isGoogleUser == true
                  ? user!.id
                  : 'local_user';
              final creatorDisplayName =
                  cloudState?.isCloudMode == true && user?.isGoogleUser == true
                  ? user!.username
                  : 'You';

              await ref
                  .read(createGroupProvider.notifier)
                  .createGroupFromInput(
                    name: name,
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    creatorId: creatorId,
                    creatorDisplayName: creatorDisplayName,
                  );

              final created = ref.read(createGroupProvider);
              if (!context.mounted || !dialogContext.mounted) return;

              created.whenOrNull(
                data: (group) {
                  Navigator.pop(dialogContext);
                  if (group != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(groupId: group.id),
                      ),
                    );
                  }
                },
                error: (error, _) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                },
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    dialog.whenComplete(() {
      nameController.dispose();
      descriptionController.dispose();
    });
  }

  void _showJoinGroupDialog(BuildContext context, WidgetRef ref) {
    final codeController = TextEditingController();
    var errorText = '';

    final dialog = showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Join Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Invite code or QR link',
                  hintText: 'ABC12345',
                  prefixIcon: Icon(Icons.qr_code_2),
                ),
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _joinGroupWithCode(
                  context,
                  dialogContext,
                  ref,
                  codeController.text,
                  (message) => setDialogState(() => errorText = message),
                ),
              ),
              if (errorText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  errorText,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _joinGroupWithCode(
                context,
                dialogContext,
                ref,
                codeController.text,
                (message) => setDialogState(() => errorText = message),
              ),
              child: const Text('Join'),
            ),
          ],
        ),
      ),
    );
    dialog.whenComplete(codeController.dispose);
  }

  Future<void> _joinGroupWithCode(
    BuildContext context,
    BuildContext dialogContext,
    WidgetRef ref,
    String rawCode,
    ValueChanged<String> setError,
  ) async {
    final code = _extractInviteCode(rawCode);
    if (code.isEmpty) {
      setError('Enter an invite code or QR link');
      return;
    }

    final result = await ref
        .read(groupRepositoryProvider)
        .findByInviteCode(code);
    if (!context.mounted || !dialogContext.mounted) return;
    if (result.error != null) {
      setError(result.error!);
      return;
    }
    final group = result.data;
    if (group == null) {
      setError('No group found for $code');
      return;
    }

    Navigator.pop(dialogContext);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: group.id)),
    );
  }

  String _extractInviteCode(String value) =>
      const CoinsInviteLinkService().extractInviteCode(value);
}

class _CloudModeCard extends StatelessWidget {
  final AsyncValue<CoinsCloudModeState> stateAsync;
  final Future<bool> Function() onEnableCloud;
  final Future<void> Function() onUseLocal;

  const _CloudModeCard({
    required this.stateAsync,
    required this.onEnableCloud,
    required this.onUseLocal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = stateAsync.value;
    final isCloud = state?.isCloudMode == true;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCloud ? Icons.cloud_done_outlined : Icons.lock_outline,
                  color: isCloud
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isCloud ? 'Cloud sharing' : 'Local-first mode',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isCloud
                  ? 'Shared groups can use your Google identity. Personal money tracking stays local unless shared.'
                  : 'Your personal transactions stay on this device. Turn on cloud sharing only when you invite people.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (state?.userLabel != 'Not signed in') ...[
              const SizedBox(height: 8),
              Text(
                state!.userLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SegmentedButton<CoinsStorageMode>(
              segments: const [
                ButtonSegment(
                  value: CoinsStorageMode.local,
                  label: Text('Local'),
                  icon: Icon(Icons.phone_android_outlined),
                ),
                ButtonSegment(
                  value: CoinsStorageMode.cloud,
                  label: Text('Cloud'),
                  icon: Icon(Icons.cloud_outlined),
                ),
              ],
              selected: {state?.mode ?? CoinsStorageMode.local},
              onSelectionChanged: stateAsync.isLoading
                  ? null
                  : (selection) {
                      if (selection.first == CoinsStorageMode.cloud) {
                        onEnableCloud();
                      } else {
                        onUseLocal();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsupportedGroupsView extends StatelessWidget {
  const _UnsupportedGroupsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Group expense splitting is available on mobile and desktop. Web support needs a non-SQLite storage backend.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _EmptyGroupsView extends StatelessWidget {
  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;

  const _EmptyGroupsView({
    required this.onCreateGroup,
    required this.onJoinGroup,
  });

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
              onPressed: onCreateGroup,
              icon: const Icon(Icons.add),
              label: const Text('Create Group'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onJoinGroup,
              icon: const Icon(Icons.link),
              label: const Text('Join with Code'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  final Group group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(currencyFormatterProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupDetailScreen(groupId: group.id),
            ),
          );
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
                    formatter.formatCents(0),
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.green),
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
