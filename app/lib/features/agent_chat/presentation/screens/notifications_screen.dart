import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/agent_notification_scheduler.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final LocalAgentNotificationScheduler _scheduler =
      LocalAgentNotificationScheduler.instance;
  late Future<List<ScheduledAgentNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _scheduler.getScheduledNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ScheduledAgentNotification>>(
      future: _notificationsFuture,
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const [];
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
                Text('Notifications (${notifications.length})'),
              ],
            ),
          ),
          body: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: _buildBody(context, snapshot, notifications),
          ),
        );
      },
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
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onDelete});

  final ScheduledAgentNotification notification;
  final VoidCallback onDelete;

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
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
              ),
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
