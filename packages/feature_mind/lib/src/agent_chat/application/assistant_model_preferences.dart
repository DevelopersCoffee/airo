import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/assistant_model_selection.dart';

const String selectedAssistantModelKey = 'selected_assistant_model_id';

final selectedAssistantModelIdProvider =
    StateNotifierProvider<SelectedAssistantModelNotifier, String?>((ref) {
      return SelectedAssistantModelNotifier();
    });

class SelectedAssistantModelNotifier extends StateNotifier<String?> {
  SelectedAssistantModelNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(selectedAssistantModelKey);
    if (cached != null) {
      state = cached;
    } else if (kIsWeb) {
      state = geminiCloudAssistantModelId;
    }
  }

  Future<void> select(String? modelId) async {
    state = modelId;
    final prefs = await SharedPreferences.getInstance();
    if (modelId == null) {
      await prefs.remove(selectedAssistantModelKey);
    } else {
      await prefs.setString(selectedAssistantModelKey, modelId);
    }
  }
}
