import 'package:flutter/material.dart';
import '../../domain/entities/group_member.dart';

/// Member Avatar Widget
///
/// Displays a user avatar with optional badge for role.
/// Used in group screens and split previews.
///
/// Phase: 2 (Split Engine)
class MemberAvatar extends StatelessWidget {
  final GroupMember? member;
  final String? displayName;
  final String? avatarUrl;
  final double size;
  final bool showRoleBadge;

  const MemberAvatar({
    super.key,
    this.member,
    this.displayName,
    this.avatarUrl,
    this.size = 40,
    this.showRoleBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = member?.displayName ?? displayName ?? 'U';
    final url = member?.avatarUrl ?? avatarUrl;
    final isAdmin = member?.role == MemberRole.admin;

    return Stack(
      children: [
        // Avatar
        CircleAvatar(
          radius: size / 2,
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage: url != null ? NetworkImage(url) : null,
          child: url == null
              ? Text(
                  name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                )
              : null,
        ),

        // Role Badge
        if (showRoleBadge && isAdmin)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.35,
              height: size * 0.35,
              decoration: BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.surface,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.star,
                size: size * 0.2,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

/// Member Avatar Stack Widget
///
/// Shows multiple avatars stacked/overlapping.
/// Used for group member previews.
class MemberAvatarStack extends StatelessWidget {
  final List<GroupMember> members;
  final int maxDisplay;
  final double avatarSize;

  const MemberAvatarStack({
    super.key,
    required this.members,
    this.maxDisplay = 3,
    this.avatarSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    final displayMembers = members.take(maxDisplay).toList();
    final overflowCount = members.length - maxDisplay;

    return SizedBox(
      height: avatarSize,
      child: Stack(
        children: [
          for (var i = 0; i < displayMembers.length; i++)
            Positioned(
              left: i * (avatarSize * 0.6),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: MemberAvatar(
                  member: displayMembers[i],
                  size: avatarSize,
                ),
              ),
            ),
          if (overflowCount > 0)
            Positioned(
              left: displayMembers.length * (avatarSize * 0.6),
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$overflowCount',
                    style: TextStyle(
                      fontSize: avatarSize * 0.35,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

