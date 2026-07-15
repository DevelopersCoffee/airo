import 'dart:convert';
import 'package:core_data/core_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/auth/auth_service.dart';
import '../../domain/models/quote_model.dart';
import '../../domain/models/quote_preferences.dart';
import '../../domain/services/quote_service.dart';

/// Quote preferences provider
final quotePreferencesProvider =
    StateNotifierProvider<QuotePreferencesNotifier, QuotePreferences>((ref) {
      return QuotePreferencesNotifier();
    });

/// Quote preferences notifier
class QuotePreferencesNotifier extends StateNotifier<QuotePreferences> {
  static const String _prefKey = 'quote_preferences';
  final int maxPreferenceValueBytes;
  SharedPreferences? _prefs;
  KeyValueStore? _store;

  QuotePreferencesNotifier({
    this.maxPreferenceValueBytes = kKeyValueStorePreferenceMaxValueBytes,
  }) : super(const QuotePreferences()) {
    _initialize();
  }

  Future<KeyValueStore> get _keyValueStore async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    _store ??= PreferencesStore(prefs, maxValueBytes: maxPreferenceValueBytes);
    return _store!;
  }

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs?.getString(_prefKey);
    if (saved != null) {
      try {
        final json = jsonDecode(saved) as Map<String, dynamic>;
        state = QuotePreferences.fromJson(json);
      } catch (e) {
        // Ignore parsing errors
      }
    }
  }

  Future<void> setShowQuotes(bool show) async {
    state = state.copyWith(showQuotes: show);
    await _savePreferences();
  }

  Future<void> setQuoteSource(String source) async {
    state = state.copyWith(quoteSource: source);
    await _savePreferences();
  }

  Future<void> _savePreferences() async {
    try {
      final store = await _keyValueStore;
      await store.setString(_prefKey, jsonEncode(state.toJson()));
    } on KeyValueStoreValueTooLargeException catch (e) {
      debugPrint('Quote preferences exceeded preference tier: $e');
    }
  }
}

/// Quote service provider
final quoteServiceProvider = Provider<QuoteService>((ref) {
  // For now, use fake service. Will switch to real service when ready
  return FakeQuoteService();

  // Uncomment below to use real ZenQuotes API:
  // final dio = ref.watch(dioProvider);
  // final prefs = await SharedPreferences.getInstance();
  // return ZenQuotesService(dio: dio, prefs: prefs);

  // Uncomment below to use ViewBits API:
  // final dio = ref.watch(dioProvider);
  // final prefs = await SharedPreferences.getInstance();
  // return ViewBitsService(
  //   dio: dio,
  //   prefs: prefs,
  //   source: QuoteSource.fortuneCookie, // or lifeHacks, uselessFacts
  // );
});

/// Daily quote provider - personalized for current user
final dailyQuoteProvider = FutureProvider<Quote>((ref) async {
  final quoteService = ref.watch(quoteServiceProvider);
  final currentUser = AuthService.instance.currentUser;

  // Use user ID for personalization, fallback to 'guest' if not logged in
  final userId = currentUser?.id ?? 'guest';

  return await quoteService.getDailyQuote(userId);
});

/// Quote refresh provider - allows manual refresh
final refreshQuoteProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(dailyQuoteProvider);
  };
});
