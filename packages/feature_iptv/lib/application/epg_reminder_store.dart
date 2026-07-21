import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:equatable/equatable.dart';

/// A scheduled reminder for an upcoming live program. Persisted as a JSON list
/// because reminder counts are small, mirroring the single-blob source stores.
class EpgReminder extends Equatable {
  const EpgReminder({
    required this.channelId,
    required this.channelName,
    required this.programId,
    required this.programTitle,
    required this.startsAt,
    required this.endsAt,
    required this.notificationId,
  });

  final String channelId;
  final String channelName;
  final String programId;
  final String programTitle;
  final DateTime startsAt;
  final DateTime endsAt;
  final int notificationId;

  factory EpgReminder.fromJson(Map<String, dynamic> json) {
    return EpgReminder(
      channelId: json['channelId'] as String,
      channelName: json['channelName'] as String,
      programId: json['programId'] as String,
      programTitle: json['programTitle'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      notificationId: json['notificationId'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    'channelName': channelName,
    'programId': programId,
    'programTitle': programTitle,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
    'notificationId': notificationId,
  };

  @override
  List<Object?> get props => [
    channelId,
    channelName,
    programId,
    programTitle,
    startsAt,
    endsAt,
    notificationId,
  ];
}

class EpgReminderStore {
  EpgReminderStore(this._store);

  static const String _storageKey = 'epg_program_reminders';

  final KeyValueStore _store;

  Future<List<EpgReminder>> list() async {
    final json = await _store.getString(_storageKey);
    if (json == null) return [];
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded
        .map((item) => EpgReminder.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(EpgReminder reminder) async {
    final reminders = await list();
    reminders.removeWhere((item) => item.programId == reminder.programId);
    reminders.add(reminder);
    await _saveAll(reminders);
  }

  Future<void> remove(String programId) async {
    final reminders = await list();
    reminders.removeWhere((item) => item.programId == programId);
    await _saveAll(reminders);
  }

  Future<bool> contains(String programId) async {
    final reminders = await list();
    return reminders.any((item) => item.programId == programId);
  }

  Future<List<EpgReminder>> pruneElapsed(DateTime now) async {
    final reminders = await list();
    final elapsed = reminders
        .where((item) => !item.endsAt.isAfter(now))
        .toList();
    if (elapsed.isEmpty) return const [];

    reminders.removeWhere((item) => !item.endsAt.isAfter(now));
    await _saveAll(reminders);
    return elapsed;
  }

  Future<void> _saveAll(List<EpgReminder> reminders) async {
    await _store.setString(
      _storageKey,
      jsonEncode(reminders.map((item) => item.toJson()).toList()),
    );
  }
}
