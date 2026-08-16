import 'package:shared_preferences/shared_preferences.dart';

import 'meeting_speaker_registry.dart';

/// Persists per-meeting speaker display names and merge aliases.
class MeetingSpeakerRegistryStore {
  MeetingSpeakerRegistryStore([SharedPreferences? preferences])
    : _preferences = preferences;

  static const _keyPrefix = 'mind.meeting_speakers.';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  String _key(String meetingId) => '$_keyPrefix$meetingId';

  Future<MeetingSpeakerRegistry> load(String meetingId) async {
    final prefs = await _prefs();
    return MeetingSpeakerRegistry.decode(prefs.getString(_key(meetingId)));
  }

  Future<void> save(String meetingId, MeetingSpeakerRegistry registry) async {
    final prefs = await _prefs();
    if (registry == MeetingSpeakerRegistry.empty) {
      await prefs.remove(_key(meetingId));
      return;
    }
    await prefs.setString(_key(meetingId), registry.encode());
  }
}
