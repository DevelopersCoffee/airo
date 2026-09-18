import '../models/alert.dart';
import 'alert_store.dart';

class InMemoryAlertStore implements AlertStore {
  final Map<String, AiroAlert> _store = {};

  @override
  Future<void> save(AiroAlert alert) async {
    _store[alert.id] = alert;
  }

  @override
  Future<AiroAlert?> get(String id) async {
    return _store[id];
  }

  @override
  Future<List<AiroAlert>> query({
    AiroAlertType? type,
    AiroAlertStatus? status,
    String? groupId,
    String? taskId,
    String? source,
    bool includeDelivered = false,
  }) async {
    return _store.values.where((alert) {
      if (type != null && alert.type != type) return false;
      if (status != null && alert.status != status) return false;
      if (groupId != null && alert.groupId != groupId) return false;
      if (taskId != null && alert.taskId != taskId) return false;
      if (source != null && alert.source != source) return false;
      if (!includeDelivered && alert.status == AiroAlertStatus.delivered) return false;
      return true;
    }).toList()
      ..sort((a, b) => (a.scheduledAt ?? a.createdAt).compareTo(b.scheduledAt ?? b.createdAt));
  }

  @override
  Future<void> updateStatus(String id, AiroAlertStatus status, {DateTime? snoozedUntil}) async {
    final existing = _store[id];
    if (existing == null) return;
    _store[id] = existing.copyWith(
      status: status,
      snoozedUntil: snoozedUntil,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    _store.removeWhere((_, alert) => alert.groupId == groupId);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }
}
