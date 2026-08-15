import 'package:shared_preferences/shared_preferences.dart';

import 'meeting_ir_user_edits.dart';

/// Persists [#1658] user corrections to action-item task/owner text.
///
/// Deliberately not the Meeting store (`saveMeeting`): IR re-extraction
/// appends a new latest-wins record and would overwrite in-place field edits.
/// Preferences survive re-extraction because they are keyed by meeting id +
/// action id, not rewritten by the extraction pipeline.
class MeetingIrUserEditsStore {
  MeetingIrUserEditsStore([SharedPreferences? preferences])
    : _preferences = preferences;

  static const _keyPrefix = 'mind.meeting_ir.user_edits.';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  String _key(String meetingId) => '$_keyPrefix$meetingId';

  Future<MeetingIrUserEdits> load(String meetingId) async {
    final prefs = await _prefs();
    return MeetingIrUserEdits.decode(prefs.getString(_key(meetingId)));
  }

  Future<void> save(String meetingId, MeetingIrUserEdits edits) async {
    final prefs = await _prefs();
    if (edits.byActionId.isEmpty) {
      await prefs.remove(_key(meetingId));
      return;
    }
    await prefs.setString(_key(meetingId), edits.encode());
  }

  Future<MeetingIrUserEdits> upsert({
    required String meetingId,
    required String actionId,
    required MeetingActionUserEdit edit,
  }) async {
    final current = await load(meetingId);
    final next = current.upsert(actionId, edit);
    await save(meetingId, next);
    return next;
  }
}
