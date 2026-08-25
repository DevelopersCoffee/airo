import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/processing_profile.dart';

const String processingProfileKey = 'mind_final_processing_profile';

final processingProfileProvider =
    StateNotifierProvider<ProcessingProfileNotifier, ProcessingProfile>(
      (ref) => ProcessingProfileNotifier(),
    );

class ProcessingProfileNotifier extends StateNotifier<ProcessingProfile> {
  ProcessingProfileNotifier() : super(ProcessingProfile.balanced) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ProcessingProfile.fromStableId(prefs.getString(processingProfileKey));
  }

  Future<void> select(ProcessingProfile profile) async {
    state = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(processingProfileKey, profile.stableId);
  }
}

Future<ProcessingProfile> loadProcessingProfile() async {
  final prefs = await SharedPreferences.getInstance();
  return ProcessingProfile.fromStableId(prefs.getString(processingProfileKey));
}
