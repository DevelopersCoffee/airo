import 'dart:async';
import '../engine/notification_engine.dart';
import '../models/action.dart';
import '../models/alert.dart';
import '../models/group.dart';
import '../models/permission.dart';
import '../storage/alert_store.dart';
import '../storage/in_memory_alert_store.dart';

class FakeAiroNotificationEngine implements AiroNotificationEngine {
  FakeAiroNotificationEngine({AlertStore? store, this.launchPayload})
      : _store = store ?? InMemoryAlertStore();

  final AlertStore _store;
  final StreamController<AiroNotificationActionEvent> _actionController =
      StreamController<AiroNotificationActionEvent>.broadcast();

  final List<AiroAlert> shownAlerts = [];
  final List<AiroAlert> scheduledAlerts = [];
  final List<String> cancelledAlertIds = [];
  final List<String> cancelledGroupIds = [];

  String? launchPayload;
  AiroNotificationPermissionStatus permissionStatus = AiroNotificationPermissionStatus.enabled;
  bool requestPermissionResult = true;

  @override
  Stream<AiroNotificationActionEvent> get onAction => _actionController.stream;

  @override
  Future<void> initialize({
    void Function(AiroNotificationActionEvent event)? onAction,
    void Function(String payload)? onNotificationPayload,
  }) async {
    if (onAction != null) {
      _actionController.stream.listen(onAction);
    }
  }

  @override
  Future<String?> getLaunchPayload() async => launchPayload;

  @override
  Future<AiroNotificationPermissionStatus> notificationPermissionStatus() async => permissionStatus;

  @override
  Future<bool> requestNotificationPermission() async => requestPermissionResult;

  @override
  Future<void> show(AiroAlert alert, {AiroNotificationGroup? group}) async {
    final updated = alert.copyWith(status: AiroAlertStatus.delivered);
    shownAlerts.add(updated);
    await _store.save(updated);
  }

  @override
  Future<AiroAlert> schedule(AiroAlert alert, {AiroNotificationGroup? group}) async {
    final updated = alert.status == AiroAlertStatus.snoozed
        ? alert
        : alert.copyWith(status: AiroAlertStatus.pending);
    scheduledAlerts.add(updated);
    await _store.save(updated);
    return updated;
  }

  @override
  Future<void> cancel(String alertId) async {
    cancelledAlertIds.add(alertId);
    await _store.delete(alertId);
  }

  @override
  Future<void> cancelGroup(String groupId) async {
    cancelledGroupIds.add(groupId);
    await _store.deleteGroup(groupId);
  }

  @override
  Future<List<AiroAlert>> query({
    AiroAlertType? type,
    AiroAlertStatus? status,
    String? groupId,
    String? taskId,
    String? source,
    bool includeDelivered = false,
  }) {
    return _store.query(
      type: type,
      status: status,
      groupId: groupId,
      taskId: taskId,
      source: source,
      includeDelivered: includeDelivered,
    );
  }

  @override
  Future<void> reschedule(String alertId, DateTime newScheduledAt) async {
    final alert = await _store.get(alertId);
    if (alert == null) return;
    final updated = alert.copyWith(
      scheduledAt: newScheduledAt,
      status: AiroAlertStatus.pending,
    );
    await schedule(updated);
  }

  @override
  Future<void> snooze(String alertId, Duration duration) async {
    final alert = await _store.get(alertId);
    if (alert == null) return;
    final snoozedUntil = DateTime.now().add(duration);
    final updated = alert.copyWith(
      scheduledAt: snoozedUntil,
      snoozedUntil: snoozedUntil,
      status: AiroAlertStatus.snoozed,
    );
    await schedule(updated);
    _actionController.add(
      AiroNotificationActionEvent(
        alertId: alertId,
        action: AiroNotificationActionType.snooze,
        snoozeDuration: duration,
      ),
    );
  }

  @override
  Future<AiroAlert?> markCompleted(String alertId) async {
    final alert = await _store.get(alertId);
    if (alert == null) return null;
    if (alert.status == AiroAlertStatus.completed) {
      return alert;
    }
    final updated = alert.copyWith(status: AiroAlertStatus.completed);
    await _store.save(updated);
    _actionController.add(
      AiroNotificationActionEvent(
        alertId: alertId,
        action: AiroNotificationActionType.complete,
        taskId: alert.taskId,
      ),
    );
    return updated;
  }

  @override
  Future<AiroAlert> persist(AiroAlert alert) async {
    await _store.save(alert);
    return alert;
  }

  void simulateUserAction(AiroNotificationActionEvent event) {
    _actionController.add(event);
  }
}
