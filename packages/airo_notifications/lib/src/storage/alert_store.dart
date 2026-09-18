import '../models/alert.dart';

abstract interface class AlertStore {
  Future<void> save(AiroAlert alert);
  Future<AiroAlert?> get(String id);
  Future<List<AiroAlert>> query({
    AiroAlertType? type,
    AiroAlertStatus? status,
    String? groupId,
    String? taskId,
    String? source,
    bool includeDelivered = false,
  });
  Future<void> updateStatus(String id, AiroAlertStatus status, {DateTime? snoozedUntil});
  Future<void> delete(String id);
  Future<void> deleteGroup(String groupId);
  Future<void> clear();
}
