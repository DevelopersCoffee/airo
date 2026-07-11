import 'package:core_ai/core_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import "package:feature_iptv/feature_iptv.dart"
    show sharedPreferencesProvider;
import 'ai_model_management.dart';

enum AIAccelerationPreference {
  auto('Auto'),
  gpuPreferred('GPU preferred'),
  cpuOnly('CPU only');

  const AIAccelerationPreference(this.label);

  final String label;
}

enum AIDownloadLocationPreference {
  internal('Internal'),
  appManaged('App managed');

  const AIDownloadLocationPreference(this.label);

  final String label;
}

class AIPreferencesSettings {
  const AIPreferencesSettings({
    this.routingStrategy = AIRoutingStrategy.onDevicePreferred,
    this.autoFallback = true,
    this.accelerationPreference = AIAccelerationPreference.auto,
    this.threadCount = 4,
    this.contextLength = 2048,
    this.memoryBudgetPercent = 60,
    this.debugLogging = false,
    this.downloadLocation = AIDownloadLocationPreference.internal,
  });

  final AIRoutingStrategy routingStrategy;
  final bool autoFallback;
  final AIAccelerationPreference accelerationPreference;
  final int threadCount;
  final int contextLength;
  final int memoryBudgetPercent;
  final bool debugLogging;
  final AIDownloadLocationPreference downloadLocation;

  AIPreferencesSettings copyWith({
    AIRoutingStrategy? routingStrategy,
    bool? autoFallback,
    AIAccelerationPreference? accelerationPreference,
    int? threadCount,
    int? contextLength,
    int? memoryBudgetPercent,
    bool? debugLogging,
    AIDownloadLocationPreference? downloadLocation,
  }) {
    return AIPreferencesSettings(
      routingStrategy: routingStrategy ?? this.routingStrategy,
      autoFallback: autoFallback ?? this.autoFallback,
      accelerationPreference:
          accelerationPreference ?? this.accelerationPreference,
      threadCount: threadCount ?? this.threadCount,
      contextLength: contextLength ?? this.contextLength,
      memoryBudgetPercent: memoryBudgetPercent ?? this.memoryBudgetPercent,
      debugLogging: debugLogging ?? this.debugLogging,
      downloadLocation: downloadLocation ?? this.downloadLocation,
    );
  }
}

final aiPreferencesSettingsProvider =
    StateNotifierProvider<AIPreferencesSettingsNotifier, AIPreferencesSettings>(
      (ref) {
        return AIPreferencesSettingsNotifier(ref);
      },
    );

final aiModelStorageUsageBytesProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(modelDownloadServiceProvider);
  return service.getStorageUsed();
});

class AIPreferencesSettingsNotifier
    extends StateNotifier<AIPreferencesSettings> {
  AIPreferencesSettingsNotifier(this._ref)
    : super(const AIPreferencesSettings()) {
    _load();
  }

  static const routingStrategyKey = 'ai_settings.routing_strategy';
  static const autoFallbackKey = 'ai_settings.auto_fallback';
  static const accelerationKey = 'ai_settings.acceleration';
  static const threadCountKey = 'ai_settings.thread_count';
  static const contextLengthKey = 'ai_settings.context_length';
  static const memoryBudgetKey = 'ai_settings.memory_budget_percent';
  static const debugLoggingKey = 'ai_settings.debug_logging';
  static const downloadLocationKey = 'ai_settings.download_location';

  final Ref _ref;

  Future<void> _load() async {
    final prefs = await _prefs();
    state = AIPreferencesSettings(
      routingStrategy: _routingStrategyFromName(
        prefs.getString(routingStrategyKey),
      ),
      autoFallback: prefs.getBool(autoFallbackKey) ?? true,
      accelerationPreference: _accelerationFromName(
        prefs.getString(accelerationKey),
      ),
      threadCount: prefs.getInt(threadCountKey) ?? 4,
      contextLength: prefs.getInt(contextLengthKey) ?? 2048,
      memoryBudgetPercent: prefs.getInt(memoryBudgetKey) ?? 60,
      debugLogging: prefs.getBool(debugLoggingKey) ?? false,
      downloadLocation: _downloadLocationFromName(
        prefs.getString(downloadLocationKey),
      ),
    );
  }

  Future<void> update(AIPreferencesSettings settings) async {
    state = settings;
    final prefs = await _prefs();
    await prefs.setString(routingStrategyKey, settings.routingStrategy.name);
    await prefs.setBool(autoFallbackKey, settings.autoFallback);
    await prefs.setString(
      accelerationKey,
      settings.accelerationPreference.name,
    );
    await prefs.setInt(threadCountKey, settings.threadCount);
    await prefs.setInt(contextLengthKey, settings.contextLength);
    await prefs.setInt(memoryBudgetKey, settings.memoryBudgetPercent);
    await prefs.setBool(debugLoggingKey, settings.debugLogging);
    await prefs.setString(downloadLocationKey, settings.downloadLocation.name);
  }

  Future<int> clearModelCache() async {
    final manager = ModelStorageManager();
    final deleted = await manager.cleanupOrphanedFiles(
      ModelCatalog.bundledModels,
    );
    _ref.invalidate(aiModelStorageUsageBytesProvider);
    return deleted.length;
  }

  Future<SharedPreferences> _prefs() async {
    try {
      return _ref.read(sharedPreferencesProvider);
    } catch (_) {
      return SharedPreferences.getInstance();
    }
  }

  static AIRoutingStrategy _routingStrategyFromName(String? raw) {
    return AIRoutingStrategy.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => AIRoutingStrategy.onDevicePreferred,
    );
  }

  static AIAccelerationPreference _accelerationFromName(String? raw) {
    return AIAccelerationPreference.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => AIAccelerationPreference.auto,
    );
  }

  static AIDownloadLocationPreference _downloadLocationFromName(String? raw) {
    return AIDownloadLocationPreference.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => AIDownloadLocationPreference.internal,
    );
  }
}
