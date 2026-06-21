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
          onComplete: () => _completeNotification(notifications[index].id),
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
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onDelete,
    required this.onComplete,
  });

  final ScheduledAgentNotification notification;
  final VoidCallback onDelete;
  final VoidCallback onComplete;

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
