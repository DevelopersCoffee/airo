import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/agent_notification_scheduler.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.scheduler,
    this.permissionService,
    this.initialCategory,
  });

  final AgentNotificationSchedulingService? scheduler;
  final AgentNotificationPermissionService? permissionService;
  final String? initialCategory;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final AgentNotificationSchedulingService _scheduler;
  late final AgentNotificationPermissionService _permissionService;
  late Future<List<ScheduledAgentNotification>> _notificationsFuture;
  late Future<AgentNotificationPermissionStatus> _permissionStatusFuture;
  bool _requestingPermission = false;

  @override
  void initState() {
    super.initState();
    _scheduler = widget.scheduler ?? LocalAgentNotificationScheduler.instance;
    _permissionService =
        widget.permissionService ?? LocalAgentNotificationScheduler.instance;
    _notificationsFuture = _scheduler.getScheduledNotifications();
    _permissionStatusFuture = _permissionService.notificationPermissionStatus();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ScheduledAgentNotification>>(
      future: _notificationsFuture,
      builder: (context, snapshot) {
        final notifications = _filteredNotifications(snapshot.data ?? const []);
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
            ),
            centerTitle: true,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications_none, size: 20),
                const SizedBox(width: 8),
                Text(_titleFor(notifications.length)),
              ],
            ),
          ),
          body: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: Column(
              children: [
                FutureBuilder<AgentNotificationPermissionStatus>(
                  future: _permissionStatusFuture,
                  builder: (context, permissionSnapshot) {
                    if (permissionSnapshot.data !=
                        AgentNotificationPermissionStatus.disabled) {
                      return const SizedBox.shrink();
                    }
                    return _NotificationPermissionCard(
                      requesting: _requestingPermission,
                      onRequest: _requestNotificationPermission,
                    );
                  },
                ),
                Expanded(child: _buildBody(context, snapshot, notifications)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _requestNotificationPermission() async {
    if (_requestingPermission) return;
    setState(() => _requestingPermission = true);
    final granted = await _permissionService.requestNotificationPermission();
    if (!mounted) return;

    setState(() {
      _requestingPermission = false;
      _permissionStatusFuture = _permissionService
          .notificationPermissionStatus();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Bell acquired. Airo can now keep you posted.'
              : 'No worries — Airo will keep updates inside the app.',
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<List<ScheduledAgentNotification>> snapshot,
    List<ScheduledAgentNotification> notifications,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (notifications.isEmpty) {
      return Center(
        child: Text(
          'No scheduled notifications',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _NotificationCard(
          notification: notifications[index],
          onDelete: () => _deleteNotification(notifications[index].id),
          onComplete: () => _completeNotification(notifications[index].id),
          onOpenInChat: () => _openNotificationInChat(notifications[index]),
        );
      },
    );
  }

  Future<void> _deleteNotification(int id) async {
    await _scheduler.cancelNotification(id);
    if (!mounted) return;
    setState(() {
      _notificationsFuture = _scheduler.getScheduledNotifications();
    });
  }

  Future<void> _completeNotification(int id) async {
    await _scheduler.markNotificationComplete(id);
    if (!mounted) return;
    setState(() {
      _notificationsFuture = _scheduler.getScheduledNotifications();
    });
  }

  void _openNotificationInChat(ScheduledAgentNotification notification) {
    final prompt = buildNotificationChatPrefill(notification);
    final uri = Uri(
      path: '/assistant/chat',
      queryParameters: prompt.isEmpty ? null : {'prefill': prompt},
    );
    context.push(uri.toString());
  }

  List<ScheduledAgentNotification> _filteredNotifications(
    List<ScheduledAgentNotification> notifications,
  ) {
    final category = widget.initialCategory?.trim();
    if (category == null || category.isEmpty) {
      return notifications;
    }
    return notifications
        .where((notification) => notification.category == category)
        .toList();
  }

  String _titleFor(int count) {
    final category = widget.initialCategory?.trim();
    if (category == null || category.isEmpty) {
      return 'Notifications ($count)';
    }
    return '${_categoryLabel(category)} Notifications ($count)';
  }
}

class _NotificationPermissionCard extends StatelessWidget {
  const _NotificationPermissionCard({
    required this.requesting,
    required this.onRequest,
  });

  final bool requesting;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Notification permission',
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        color: colors.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_active_outlined, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Let Airo ring the tiny bell?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Turn on notifications so downloads, reminders, and '
                      'recordings don’t finish in mysterious silence.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: requesting ? null : onRequest,
                      icon: requesting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.notifications_active_outlined),
                      label: Text(
                        requesting ? 'Asking nicely…' : 'Yes, keep me posted',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onDelete,
    required this.onComplete,
    required this.onOpenInChat,
  });

  final ScheduledAgentNotification notification;
  final VoidCallback onDelete;
  final VoidCallback onComplete;
  final VoidCallback onOpenInChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(notification.message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_categoryLabel(notification.category)),
                ),
                if (notification.requiresCompletion)
                  const Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(Icons.repeat, size: 16),
                    label: Text('Until done'),
                  ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.local_fire_department, size: 16),
                  label: Text('${notification.streakCount} day streak'),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.stars, size: 16),
                  label: Text('${notification.points} pts'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Time: ${_formatTime(notification.hour, notification.minute)}',
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                Text(
                  notification.repeatDaily ? 'Daily' : 'Once',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenInChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Open in chat'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _completedToday(notification) ? null : onComplete,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    _completedToday(notification) ? 'Done today' : 'Done',
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

String _formatTime(int hour, int minute) {
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hour12:${minute.toString().padLeft(2, '0')} $period';
}

String _categoryLabel(String category) {
  return switch (category) {
    'medicine' => 'Medicine',
    'billing' => 'Bills',
    'family' => 'Family',
    'habit' => 'Habit',
    'downloads' => 'Downloads',
    'recording' => 'Recording',
    _ => 'Reminder',
  };
}

bool _completedToday(ScheduledAgentNotification notification) {
  final now = DateTime.now();
  final today =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  return notification.completedDates.contains(today);
}

String buildNotificationChatPrefill(ScheduledAgentNotification notification) {
  final parts = <String>[
    notification.title.trim(),
    notification.message.trim(),
  ].where((part) => part.isNotEmpty).toList();

  final context = <String>[
    if (notification.repeatDaily)
      'daily at ${_formatTime(notification.hour, notification.minute)}'
    else if (notification.date != null && notification.date!.isNotEmpty)
      'on ${notification.date} at ${_formatTime(notification.hour, notification.minute)}'
    else
      'at ${_formatTime(notification.hour, notification.minute)}',
  ];

  if (parts.isEmpty) {
    return '';
  }

  return 'Help me with this reminder: ${parts.join(' - ')} (${context.join(', ')}).';
}
