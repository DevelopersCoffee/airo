import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/assistant_model_selection.dart';
import '../domain/models/assistant_runtime_ids.dart';

const String selectedAssistantModelKey = 'selected_assistant_model_id';
const String selectedOfflineModelKey = 'selected_offline_model_id';

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
      await prefs.remove(selectedOfflineModelKey);
    } else {
      await prefs.setString(selectedAssistantModelKey, modelId);
      final offlineId = offlineModelIdFromAssistantModelId(modelId);
      if (offlineId != null) {
        await prefs.setString(selectedOfflineModelKey, offlineId);
      }
    }
  }
}
