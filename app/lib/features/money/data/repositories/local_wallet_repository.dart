import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/wallet_repository.dart';

/// Local storage implementation of WalletRepository
/// Uses SharedPreferences for persistence with JSON serialization
/// Thread-safe with proper error handling for financial data
class LocalWalletRepository implements WalletRepository {
  static const String _storageKey = 'airo_wallets_v1';
  static const String _userIdKey = 'airo_current_user_id';

  final Uuid _uuid = const Uuid();
  SharedPreferences? _prefs;

  /// In-memory cache for performance
  Map<String, Wallet>? _cache;

  /// Get SharedPreferences instance
  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Get storage key for current user (wallets are user-specific)
  Future<String> get _userStorageKey async {
    final prefs = await _preferences;
    final userId = prefs.getString(_userIdKey) ?? 'default';
    return '${_storageKey}_$userId';
  }

  /// Load wallets from storage into cache
  Future<void> _loadCache() async {
    if (_cache != null) return;

    try {
      final prefs = await _preferences;
      final key = await _userStorageKey;
      final jsonStr = prefs.getString(key);

      if (jsonStr == null) {
        _cache = {};
        return;
      }

      final List<dynamic> jsonList = jsonDecode(jsonStr);
      _cache = {
        for (final json in jsonList)
          json['id'] as String: Wallet.fromJson(json as Map<String, dynamic>)
      };
    } catch (e) {
      debugPrint('Error loading wallets: $e');
      _cache = {};
    }
  }

  /// Save cache to storage
  Future<void> _saveCache() async {
    if (_cache == null) return;

    try {
      final prefs = await _preferences;
      final key = await _userStorageKey;
      final jsonList = _cache!.values.map((w) => w.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving wallets: $e');
      throw Exception('Failed to save wallet data: $e');
    }
  }

  /// Invalidate cache (call when user changes)
  void invalidateCache() {
    _cache = null;
  }

  @override
  Future<Result<List<Wallet>>> fetchAll() async {
    try {
      await _loadCache();
      final wallets = _cache!.values.where((w) => w.isActive).toList();
      wallets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Ok(wallets);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<Wallet>> fetchById(String id) async {
    try {
      await _loadCache();
      final wallet = _cache![id];
      if (wallet == null) {
        return Err(Exception('Wallet not found: $id'), StackTrace.current);
      }
      return Ok(wallet);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<Wallet>> create({
    required String name,
    String? description,
    required int balanceCents,
    required WalletType type,
    required String currency,
    String? bankName,
    String? accountNumber,
  }) async {
    try {
      await _loadCache();

      final now = DateTime.now();
      final wallet = Wallet(
        id: _uuid.v4(),
        name: name.trim(),
        description: description?.trim(),
        balanceCents: balanceCents,
        type: type,
        currency: currency,
        bankName: bankName?.trim(),
        accountNumber: accountNumber?.trim(),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      _cache![wallet.id] = wallet;
      await _saveCache();

      return Ok(wallet);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<Wallet>> update(Wallet wallet) async {
    try {
      await _loadCache();

      if (!_cache!.containsKey(wallet.id)) {
        return Err(
          Exception('Wallet not found: ${wallet.id}'),
          StackTrace.current,
        );
      }

      final updated = wallet.copyWith(updatedAt: DateTime.now());
      _cache![wallet.id] = updated;
      await _saveCache();

      return Ok(updated);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _loadCache();
      final wallet = _cache![id];
      if (wallet != null) {
        _cache![id] = wallet.copyWith(isActive: false, updatedAt: DateTime.now());
        await _saveCache();
      }
      return const Ok(null);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<Wallet>> updateBalance(String id, int newBalanceCents) async {
    try {
      await _loadCache();
      final wallet = _cache![id];
      if (wallet == null) {
        return Err(Exception('Wallet not found: $id'), StackTrace.current);
      }
      final updated = wallet.copyWith(
        balanceCents: newBalanceCents,
        updatedAt: DateTime.now(),
      );
      _cache![id] = updated;
      await _saveCache();
      return Ok(updated);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<int>> getTotalBalanceCents() async {
    try {
      await _loadCache();
      final total = _cache!.values
          .where((w) => w.isActive)
          .fold<int>(0, (sum, w) => sum + w.balanceCents);
      return Ok(total);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  // CacheRepository implementation
  @override
  Future<Wallet?> get(String id) async {
    await _loadCache();
    return _cache![id];
  }

  @override
  Future<void> put(String id, Wallet data) async {
    await _loadCache();
    _cache![id] = data;
    await _saveCache();
  }

  @override
  Future<List<Wallet>> getAll() async {
    await _loadCache();
    return _cache!.values.toList();
  }

  @override
  Future<bool> exists(String id) async {
    await _loadCache();
    return _cache!.containsKey(id);
  }

  @override
  Future<void> clear() async {
    _cache = {};
    await _saveCache();
  }
}

