import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/providers/cloud_mode_provider.dart';
import '../../application/providers/group_providers.dart';
import '../../application/services/coins_invite_link_service.dart';
import '../../domain/entities/group.dart';

/// Cloud-backed group invite share for the super-app profile.
Future<void> shareGroupInviteWithCloud(
  BuildContext context,
  WidgetRef ref,
  Group group,
) async {
  final cloudState = ref.read(coinsCloudModeControllerProvider).value;
  var isCloudMode = cloudState?.isCloudMode == true;
  var user = cloudState?.user;

  if (!isCloudMode || user?.isGoogleIdentity != true) {
    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Switch to cloud sharing?'),
        content: const Text(
          'Group invites need your Google identity so peers can sync shared expenses. Personal transactions stay local.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.cloud_outlined),
            label: const Text('Use Cloud'),
          ),
        ],
      ),
    );
    if (shouldEnable != true || !context.mounted) return;

    isCloudMode = await ref
        .read(coinsCloudModeControllerProvider.notifier)
        .enableCloudMode();
    user = ref.read(coinsCloudModeControllerProvider).value?.user;
    if (!context.mounted) return;
    if (!isCloudMode || user?.isGoogleIdentity != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google sign-in is required to share')),
      );
      return;
    }
  }

  var inviteCode = group.inviteCode;
  if (inviteCode == null || inviteCode.isEmpty) {
    final result = await ref
        .read(groupRepositoryProvider)
        .generateInviteCode(group.id);
    if (!context.mounted) return;
    if (result.error != null || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Could not create invite')),
      );
      return;
    }
    inviteCode = result.data!;
  }

  final link = const CoinsInviteLinkService().buildInviteLink(
    groupId: group.id,
    inviteCode: inviteCode,
    ownerUserId: user!.id,
    cloudMode: true,
  );
  await SharePlus.instance.share(
    ShareParams(
      text: 'Join ${group.name} on Airo Coins: $link',
      subject: 'Airo Coins group invite',
    ),
  );
}
