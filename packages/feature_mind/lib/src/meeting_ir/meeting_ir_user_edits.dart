import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../whisper/api/meetings.dart' as rust;

/// One user correction to an extracted action item (#1658).
///
/// Stored separately from the Meeting IR write path so a later re-extraction
/// (which re-saves via `saveMeeting`) never silently overwrites the person's
/// edits. Display merges these over the persisted IR fields.
@immutable
class MeetingActionUserEdit {
  const MeetingActionUserEdit({this.task, this.owner});

  /// Corrected task text. Null means "keep the IR value".
  final String? task;

  /// Corrected owner. Empty string clears an inferred/wrong owner; null means
  /// "keep the IR value".
  final String? owner;

  MeetingActionUserEdit copyWith({String? task, String? owner}) =>
      MeetingActionUserEdit(
        task: task ?? this.task,
        owner: owner ?? this.owner,
      );

  Map<String, Object?> toJson() => {
    if (task != null) 'task': task,
    if (owner != null) 'owner': owner,
  };

  static MeetingActionUserEdit fromJson(Map<String, Object?> json) =>
      MeetingActionUserEdit(
        task: json['task'] as String?,
        owner: json['owner'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeetingActionUserEdit &&
          task == other.task &&
          owner == other.owner;

  @override
  int get hashCode => Object.hash(task, owner);
}

/// Per-meeting map of action-item id → user edit.
@immutable
class MeetingIrUserEdits {
  const MeetingIrUserEdits({this.byActionId = const {}});

  final Map<String, MeetingActionUserEdit> byActionId;

  MeetingIrUserEdits upsert(String actionId, MeetingActionUserEdit edit) =>
      MeetingIrUserEdits(byActionId: {...byActionId, actionId: edit});

  MeetingActionUserEdit? operator [](String actionId) => byActionId[actionId];

  /// Display task: user edit wins, else IR.
  String taskFor(rust.MeetingActionItemRecord item) =>
      byActionId[item.id]?.task ?? item.task;

  /// Display owner: user edit wins (including explicit clear via ''), else IR.
  String? ownerFor(rust.MeetingActionItemRecord item) {
    final edit = byActionId[item.id];
    if (edit == null || edit.owner == null) return item.owner;
    final owner = edit.owner!;
    return owner.isEmpty ? null : owner;
  }

  Map<String, Object?> toJson() => {
    for (final e in byActionId.entries) e.key: e.value.toJson(),
  };

  static MeetingIrUserEdits fromJson(Map<String, Object?> json) {
    final map = <String, MeetingActionUserEdit>{};
    for (final e in json.entries) {
      final value = e.value;
      if (value is Map<String, Object?>) {
        map[e.key] = MeetingActionUserEdit.fromJson(value);
      } else if (value is Map) {
        map[e.key] = MeetingActionUserEdit.fromJson(
          value.cast<String, Object?>(),
        );
      }
    }
    return MeetingIrUserEdits(byActionId: map);
  }

  static MeetingIrUserEdits decode(String? raw) {
    if (raw == null || raw.isEmpty) return const MeetingIrUserEdits();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const MeetingIrUserEdits();
    return MeetingIrUserEdits.fromJson(decoded.cast<String, Object?>());
  }

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeetingIrUserEdits && mapEquals(byActionId, other.byActionId);

  @override
  int get hashCode => Object.hashAll(byActionId.entries);
}
