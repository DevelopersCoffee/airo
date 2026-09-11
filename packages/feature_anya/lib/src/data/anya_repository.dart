import 'dart:convert';

import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plaintext prefs key used by the first slice. Migrated away on load.
const anyaSnapshotPrefsKey = 'anya.snapshot.v1';

/// Encrypted (Keychain / Keystore) snapshot key.
const anyaSnapshotSecretKey = 'anya.snapshot.v2';

class AnyaSnapshot {
  const AnyaSnapshot({
    this.profile,
    this.weeklyPlan,
    this.programs = const [],
    this.activeProgramId,
    this.checkedGroceryKeys = const {},
  });

  final DietProfile? profile;
  final WeeklyPlan? weeklyPlan;
  final List<DietProgram> programs;
  final String? activeProgramId;
  final Set<String> checkedGroceryKeys;

  DietProgram? get activeProgram {
    final id = activeProgramId;
    if (id == null) return null;
    for (final program in programs) {
      if (program.id == id) return program;
    }
    return null;
  }

  GroceryList get groceryList {
    final catalog = weeklyPlan == null
        ? const GroceryList(lines: [])
        : groceryListFromWeeklyPlan(weeklyPlan!);
    final program = activeProgram;
    if (program == null) return catalog;
    return mergeGroceryLists(catalog, groceryListFromProgram(program));
  }

  AnyaSnapshot copyWith({
    DietProfile? profile,
    WeeklyPlan? weeklyPlan,
    List<DietProgram>? programs,
    String? activeProgramId,
    Set<String>? checkedGroceryKeys,
    bool clearPlan = false,
    bool clearActiveProgram = false,
  }) => AnyaSnapshot(
    profile: profile ?? this.profile,
    weeklyPlan: clearPlan ? null : weeklyPlan ?? this.weeklyPlan,
    programs: programs ?? this.programs,
    activeProgramId: clearActiveProgram
        ? null
        : activeProgramId ?? this.activeProgramId,
    checkedGroceryKeys: checkedGroceryKeys ?? this.checkedGroceryKeys,
  );
}

abstract class AnyaRepository {
  Future<AnyaSnapshot> load();
  Future<void> save(AnyaSnapshot snapshot);
}

class MemoryAnyaRepository implements AnyaRepository {
  MemoryAnyaRepository([this._snapshot = const AnyaSnapshot()]);

  AnyaSnapshot _snapshot;

  @override
  Future<AnyaSnapshot> load() async => _snapshot;

  @override
  Future<void> save(AnyaSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}

AnyaSnapshot decodeAnyaSnapshot(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return AnyaSnapshot(
    profile: json['profile'] == null
        ? null
        : DietProfile.fromJson(
            Map<String, Object?>.from(json['profile'] as Map),
          ),
    weeklyPlan: json['weeklyPlan'] == null
        ? null
        : WeeklyPlan.fromJson(
            Map<String, Object?>.from(json['weeklyPlan'] as Map),
          ),
    programs: [
      for (final item in json['programs'] as List<dynamic>? ?? const [])
        DietProgram.fromJson(Map<String, Object?>.from(item as Map)),
    ],
    activeProgramId: json['activeProgramId'] as String?,
    checkedGroceryKeys: {
      for (final key
          in json['checkedGroceryKeys'] as List<dynamic>? ?? const [])
        key as String,
    },
  );
}

String encodeAnyaSnapshot(AnyaSnapshot snapshot) => jsonEncode({
  'profile': snapshot.profile?.toJson(),
  'weeklyPlan': snapshot.weeklyPlan?.toJson(),
  'programs': snapshot.programs.map((p) => p.toJson()).toList(),
  'activeProgramId': snapshot.activeProgramId,
  'checkedGroceryKeys': snapshot.checkedGroceryKeys.toList(),
});

class SharedPreferencesAnyaRepository implements AnyaRepository {
  SharedPreferencesAnyaRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<AnyaSnapshot> load() async {
    final raw = _prefs.getString(anyaSnapshotPrefsKey);
    if (raw == null) return const AnyaSnapshot();
    return decodeAnyaSnapshot(raw);
  }

  @override
  Future<void> save(AnyaSnapshot snapshot) async {
    await _prefs.setString(anyaSnapshotPrefsKey, encodeAnyaSnapshot(snapshot));
  }
}

/// Key-value secret store so tests do not need the platform plugin.
abstract class AnyaSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class MemoryAnyaSecretStore implements AnyaSecretStore {
  MemoryAnyaSecretStore([Map<String, String>? values])
    : _values = values ?? <String, String>{};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

class FlutterAnyaSecretStore implements AnyaSecretStore {
  FlutterAnyaSecretStore([FlutterSecureStorage? storage])
    : _storage = storage ?? _createStorage();

  final FlutterSecureStorage _storage;

  static FlutterSecureStorage _createStorage() => const FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'airo_anya_secure',
      preferencesKeyPrefix: 'anya_',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      accountName: 'airo_anya',
    ),
    webOptions: WebOptions(
      dbName: 'airo_anya_secure_storage',
      publicKey: 'airo_anya_public_key',
    ),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Health-adjacent snapshot in secure storage. Migrates plaintext v1 prefs.
class SecureAnyaRepository implements AnyaRepository {
  SecureAnyaRepository({required this.secrets, this.plaintextFallback});

  final AnyaSecretStore secrets;
  final SharedPreferences? plaintextFallback;

  @override
  Future<AnyaSnapshot> load() async {
    final encrypted = await secrets.read(anyaSnapshotSecretKey);
    if (encrypted != null && encrypted.isNotEmpty) {
      return decodeAnyaSnapshot(encrypted);
    }
    final prefs = plaintextFallback;
    final leftover = prefs?.getString(anyaSnapshotPrefsKey);
    if (leftover == null || leftover.isEmpty) return const AnyaSnapshot();
    final snapshot = decodeAnyaSnapshot(leftover);
    await save(snapshot);
    await prefs!.remove(anyaSnapshotPrefsKey);
    return snapshot;
  }

  @override
  Future<void> save(AnyaSnapshot snapshot) async {
    await secrets.write(anyaSnapshotSecretKey, encodeAnyaSnapshot(snapshot));
    await plaintextFallback?.remove(anyaSnapshotPrefsKey);
  }
}
