import 'package:core_ai/core_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live catalog the Intelligence UI ranks against. Shells override this with
/// the hydrated registry; the default is the bundled catalog only.
final intelligenceCatalogProvider = Provider<List<OfflineModelInfo>>((ref) {
  return ModelCatalog.bundledModels;
});

final intelligenceMemoryLoaderProvider = FutureProvider<MemoryInfo?>((
  ref,
) async {
  try {
    return await DeviceCapabilityService().getMemoryInfo(forceRefresh: true);
  } on Object {
    return null;
  }
});

final intelligenceMemoryProvider = Provider<MemoryInfo?>((ref) {
  return ref.watch(intelligenceMemoryLoaderProvider).asData?.value;
});

final intelligenceStorageUsedBytesProvider = Provider<int>((ref) {
  final catalog = ref.watch(intelligenceCatalogProvider);
  return catalog
      .where((model) => model.isDownloaded)
      .fold<int>(0, (sum, model) => sum + model.fileSizeBytes);
});

const String intelligenceOverridePrefix = 'intelligence_slot_override_';

final intelligenceOverridesProvider =
    StateNotifierProvider<IntelligenceOverridesNotifier, Map<String, String>>((
      ref,
    ) {
      return IntelligenceOverridesNotifier();
    });

class IntelligenceOverridesNotifier extends StateNotifier<Map<String, String>> {
  IntelligenceOverridesNotifier() : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(intelligenceOverridePrefix)) continue;
      final value = prefs.getString(key);
      if (value == null || value.isEmpty) continue;
      loaded[key.substring(intelligenceOverridePrefix.length)] = value;
    }
    if (loaded.isNotEmpty) state = loaded;
  }

  Future<void> setOverride(String slotKey, String? modelId) async {
    final prefs = await SharedPreferences.getInstance();
    final next = Map<String, String>.from(state);
    if (modelId == null || modelId.isEmpty) {
      next.remove(slotKey);
      await prefs.remove('$intelligenceOverridePrefix$slotKey');
    } else {
      next[slotKey] = modelId;
      await prefs.setString('$intelligenceOverridePrefix$slotKey', modelId);
    }
    state = next;
  }
}
