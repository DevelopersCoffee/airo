import 'dart:io';

import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/live_intelligence_mode.dart';
import '../../mind_store_paths.dart';

const String liveInsightsEnabledKey = 'mind_live_insights_enabled';
const String liveInsightsAutoExpandKey = 'mind_live_insights_auto_expand';
const String liveIntelligenceModeKey = 'mind_live_intelligence_mode';

final liveInsightsEnabledProvider =
    StateNotifierProvider<LiveInsightsEnabledNotifier, bool>(
      (ref) => LiveInsightsEnabledNotifier(),
    );

final liveInsightsAutoExpandProvider =
    StateNotifierProvider<LiveInsightsAutoExpandNotifier, bool>(
      (ref) => LiveInsightsAutoExpandNotifier(),
    );

final liveIntelligenceModeProvider =
    StateNotifierProvider<LiveIntelligenceModeNotifier, LiveIntelligenceMode>(
      (ref) => LiveIntelligenceModeNotifier(),
    );

class LiveInsightsEnabledNotifier extends StateNotifier<bool> {
  LiveInsightsEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(liveInsightsEnabledKey) ?? true;
  }

  Future<void> select(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(liveInsightsEnabledKey, enabled);
  }
}

class LiveInsightsAutoExpandNotifier extends StateNotifier<bool> {
  LiveInsightsAutoExpandNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(liveInsightsAutoExpandKey) ?? false;
  }

  Future<void> select(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(liveInsightsAutoExpandKey, enabled);
  }
}

class LiveIntelligenceModeNotifier extends StateNotifier<LiveIntelligenceMode> {
  LiveIntelligenceModeNotifier() : super(LiveIntelligenceMode.fallback) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = LiveIntelligenceMode.fromStorageValue(
      prefs.getString(liveIntelligenceModeKey),
    );
    await persistLiveIntelligenceModeToNative(state);
  }

  Future<void> select(LiveIntelligenceMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(liveIntelligenceModeKey, mode.storageValue);
    await persistLiveIntelligenceModeToNative(mode);
  }
}

/// Sidecar Rust reads at `start_live_session` (store parent).
///
/// That parent is `{applicationSupport}/airo_mind`, not application support
/// itself — see [mindStoreParentDirectory]. This wrote one segment short, so
/// `read_live_intelligence_mode` never found the file and silently fell back
/// to "automatic", making the setting inert.
Future<void> persistLiveIntelligenceModeToNative(
  LiveIntelligenceMode mode,
) async {
  try {
    final dir = await mindStoreParentDirectory();
    File(
      p.join(dir.path, 'mind_live_intelligence_mode'),
    ).writeAsStringSync(mode.storageValue);
  } on Object {
    // Host tests and web have no path_provider channel.
  }
}
