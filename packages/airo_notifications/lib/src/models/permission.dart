enum AiroNotificationPermissionStatus { enabled, disabled, unavailable }

class NotificationPermissionDeniedException implements Exception {
  const NotificationPermissionDeniedException([this.message = 'Notification permission denied.']);
  final String message;

  @override
  String toString() => 'NotificationPermissionDeniedException: $message';
}
