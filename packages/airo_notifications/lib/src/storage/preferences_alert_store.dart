import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';
import 'alert_store.dart';

class PreferencesAlertStore implements AlertStore {
  PreferencesAlertStore([SharedPreferencesAsync? preferences])
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _storageKey = 'airo_notifications_store_v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<void> save(AiroAlert alert) async {
    final items = await _loadAll();
    items[alert.id] = alert;
    await _saveAll(items);
  }

  @override
  Future<AiroAlert?> get(String id) async {
    final items = await _loadAll();
    return items[id];
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
    final items = await _loadAll();
    return items.values.where((alert) {
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
    final items = await _loadAll();
    final existing = items[id];
    if (existing == null) return;
    items[id] = existing.copyWith(
      status: status,
      snoozedUntil: snoozedUntil,
      updatedAt: DateTime.now(),
    );
    await _saveAll(items);
  }

  @override
  Future<void> delete(String id) async {
    final items = await _loadAll();
    items.remove(id);
    await _saveAll(items);
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    final items = await _loadAll();
    items.removeWhere((_, alert) => alert.groupId == groupId);
    await _saveAll(items);
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_storageKey);
  }

  Future<Map<String, AiroAlert>> _loadAll() async {
    var raw = await _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      raw = await _preferences.getString('agent_scheduled_notifications_v1');
    }
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      final map = <String, AiroAlert>{};
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          if (entry.value is Map) {
            map[entry.key] = AiroAlert.fromJson(
              Map<String, Object?>.from(entry.value as Map),
            );
          }
        }
      } else if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            final alert = AiroAlert.fromJson(Map<String, Object?>.from(item));
            map[alert.id] = alert;
          }
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveAll(Map<String, AiroAlert> items) async {
    final jsonMap = <String, Object?>{
      for (final entry in items.entries) entry.key: entry.value.toJson(),
    };
    await _preferences.setString(_storageKey, jsonEncode(jsonMap));
  }
}
