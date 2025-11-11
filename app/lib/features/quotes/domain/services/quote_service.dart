import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quote_model.dart';

/// Quote source types
enum QuoteSource {
  zenQuotes,
  fortuneCookie,
  lifeHacks,
  uselessFacts,
  mixed, // Randomly picks from all sources
}

/// Service for fetching and managing daily quotes
abstract interface class QuoteService {
  /// Get personalized daily quote for a user
  Future<Quote> getDailyQuote(String userId);

  /// Fetch fresh quotes from API
  Future<List<Quote>> fetchQuotes({int count = 50});

  /// Clear cached quotes
  Future<void> clearCache();
}

/// Implementation using ZenQuotes API
class ZenQuotesService implements QuoteService {
  static const String _baseUrl = 'https://zenquotes.io/api';
  static const String _cacheKey = 'cached_quotes';
  static const String _lastFetchKey = 'quotes_last_fetch';
  static const Duration _cacheDuration = Duration(days: 7);

  final Dio _dio;
  final SharedPreferences _prefs;

  ZenQuotesService({required Dio dio, required SharedPreferences prefs})
    : _dio = dio,
      _prefs = prefs;

  @override
  Future<Quote> getDailyQuote(String userId) async {
    try {
      // Get cached quotes or fetch new ones
      final quotes = await _getCachedOrFetchQuotes();

      if (quotes.isEmpty) {
        return const Quote(
          text: 'Every day is a new opportunity to grow.',
          author: 'Airo',
        );
      }

      // Generate a deterministic index based on userId + current date
      // This ensures the same user gets the same quote all day,
      // but different users get different quotes
      final today = DateTime.now();
      final dateString = '${today.year}-${today.month}-${today.day}';
      final seed = '${userId}_$dateString'.hashCode.abs();
      final index = seed % quotes.length;

      return quotes[index];
    } catch (e) {
      // Fallback quote if everything fails
      return const Quote(
        text: 'The journey of a thousand miles begins with a single step.',
        author: 'Lao Tzu',
      );
    }
  }

  @override
  Future<List<Quote>> fetchQuotes({int count = 50}) async {
    try {
      // ZenQuotes API endpoint for today's quote (we'll call it multiple times)
      // Note: ZenQuotes has rate limits, so we use the /quotes endpoint
      final response = await _dio.get(
        '$_baseUrl/quotes',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        final quotes = (response.data as List)
            .map((json) => Quote.fromJson(json as Map<String, dynamic>))
            .toList();

        // Cache the quotes
        await _cacheQuotes(quotes);

        return quotes;
      }

      return [];
    } catch (e) {
      // Return cached quotes if fetch fails
      return _getCachedQuotes();
    }
  }

  @override
  Future<void> clearCache() async {
    await _prefs.remove(_cacheKey);
    await _prefs.remove(_lastFetchKey);
  }

  /// Get cached quotes or fetch new ones if cache is stale
  Future<List<Quote>> _getCachedOrFetchQuotes() async {
    final lastFetch = _prefs.getString(_lastFetchKey);
    final now = DateTime.now();

    // Check if cache is still valid
    if (lastFetch != null) {
      final lastFetchDate = DateTime.parse(lastFetch);
      final difference = now.difference(lastFetchDate);

      if (difference < _cacheDuration) {
        final cached = _getCachedQuotes();
        if (cached.isNotEmpty) {
          return cached;
        }
      }
    }

    // Cache is stale or empty, fetch new quotes
    return await fetchQuotes();
  }

  /// Get quotes from cache
  List<Quote> _getCachedQuotes() {
    final cached = _prefs.getString(_cacheKey);
    if (cached == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(cached);
      return jsonList
          .map((json) => Quote.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Cache quotes to local storage
  Future<void> _cacheQuotes(List<Quote> quotes) async {
    final jsonList = quotes.map((q) => q.toJson()).toList();
    await _prefs.setString(_cacheKey, jsonEncode(jsonList));
    await _prefs.setString(_lastFetchKey, DateTime.now().toIso8601String());
  }
}

/// ViewBits API Service - No API key required!
class ViewBitsService implements QuoteService {
  static const String _baseUrl = 'https://api.viewbits.com';
  static const String _cacheKey = 'cached_viewbits_quotes';
  static const String _lastFetchKey = 'viewbits_last_fetch';
  static const Duration _cacheDuration = Duration(days: 7);

  final Dio _dio;
  final SharedPreferences _prefs;
  final QuoteSource _source;

  ViewBitsService({
    required Dio dio,
    required SharedPreferences prefs,
    QuoteSource source = QuoteSource.fortuneCookie,
  }) : _dio = dio,
       _prefs = prefs,
       _source = source;

  @override
  Future<Quote> getDailyQuote(String userId) async {
    try {
      final quotes = await _getCachedOrFetchQuotes();
      if (quotes.isEmpty) {
        return _getFallbackQuote();
      }

      final today = DateTime.now();
      final dateString = '${today.year}-${today.month}-${today.day}';
      final seed = '${userId}_$dateString'.hashCode.abs();
      final index = seed % quotes.length;

      return quotes[index];
    } catch (e) {
      return _getFallbackQuote();
    }
  }

  @override
  Future<List<Quote>> fetchQuotes({int count = 50}) async {
    try {
      final endpoint = _getEndpoint();
      final quotes = <Quote>[];

      // Fetch multiple times to build a collection
      for (var i = 0; i < 10; i++) {
        final response = await _dio.get(
          endpoint,
          options: Options(
            receiveTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
          ),
        );

        if (response.statusCode == 200) {
          final quote = _parseResponse(response.data);
          if (quote != null && !quotes.contains(quote)) {
            quotes.add(quote);
          }
        }

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (quotes.isNotEmpty) {
        await _cacheQuotes(quotes);
      }

      return quotes;
    } catch (e) {
      return _getCachedQuotes();
    }
  }

  @override
  Future<void> clearCache() async {
    await _prefs.remove(_cacheKey);
    await _prefs.remove(_lastFetchKey);
  }

  String _getEndpoint() {
    return switch (_source) {
      QuoteSource.fortuneCookie => '$_baseUrl/fortune-cookie',
      QuoteSource.lifeHacks => '$_baseUrl/life-hacks',
      QuoteSource.uselessFacts => '$_baseUrl/useless-facts',
      _ => '$_baseUrl/fortune-cookie',
    };
  }

  Quote? _parseResponse(dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        // Fortune Cookie format
        if (data.containsKey('fortune')) {
          return Quote(
            text: data['fortune'] as String,
            author: 'Fortune Cookie',
          );
        }
        // Life Hacks format
        if (data.containsKey('hack')) {
          return Quote(text: data['hack'] as String, author: 'Life Hack');
        }
        // Useless Facts format
        if (data.containsKey('fact')) {
          return Quote(
            text: data['fact'] as String,
            author: 'Interesting Fact',
          );
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return null;
  }

  Quote _getFallbackQuote() {
    return const Quote(
      text: 'Every day is a new opportunity to grow.',
      author: 'Airo',
    );
  }

  Future<List<Quote>> _getCachedOrFetchQuotes() async {
    final lastFetch = _prefs.getString(_lastFetchKey);
    final now = DateTime.now();

    if (lastFetch != null) {
      final lastFetchDate = DateTime.parse(lastFetch);
      final difference = now.difference(lastFetchDate);

      if (difference < _cacheDuration) {
        final cached = _getCachedQuotes();
        if (cached.isNotEmpty) {
          return cached;
        }
      }
    }

    return await fetchQuotes();
  }

  List<Quote> _getCachedQuotes() {
    final cached = _prefs.getString(_cacheKey);
    if (cached == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(cached);
      return jsonList
          .map((json) => Quote.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _cacheQuotes(List<Quote> quotes) async {
    final jsonList = quotes.map((q) => q.toJson()).toList();
    await _prefs.setString(_cacheKey, jsonEncode(jsonList));
    await _prefs.setString(_lastFetchKey, DateTime.now().toIso8601String());
  }
}

/// Fake implementation for testing
class FakeQuoteService implements QuoteService {
  static final List<Quote> _quotes = [
    const Quote(
      text: 'The only way to do great work is to love what you do.',
      author: 'Steve Jobs',
    ),
    const Quote(
      text: 'Innovation distinguishes between a leader and a follower.',
      author: 'Steve Jobs',
    ),
    const Quote(
      text:
          'Your time is limited, don\'t waste it living someone else\'s life.',
      author: 'Steve Jobs',
    ),
    const Quote(
      text:
          'The future belongs to those who believe in the beauty of their dreams.',
      author: 'Eleanor Roosevelt',
    ),
    const Quote(
      text:
          'Success is not final, failure is not fatal: it is the courage to continue that counts.',
      author: 'Winston Churchill',
    ),
    const Quote(
      text: 'A journey of a thousand miles begins with a single step.',
      author: 'Lao Tzu',
    ),
    const Quote(
      text: 'Believe you can and you\'re halfway there.',
      author: 'Theodore Roosevelt',
    ),
    const Quote(
      text:
          'The best time to plant a tree was 20 years ago. The second best time is now.',
      author: 'Chinese Proverb',
    ),
    const Quote(
      text: 'Life is 10% what happens to you and 90% how you react to it.',
      author: 'Charles R. Swindoll',
    ),
    const Quote(
      text: 'The only impossible journey is the one you never begin.',
      author: 'Tony Robbins',
    ),
  ];

  @override
  Future<Quote> getDailyQuote(String userId) async {
    final today = DateTime.now();
    final dateString = '${today.year}-${today.month}-${today.day}';
    final seed = '${userId}_$dateString'.hashCode.abs();
    final index = seed % _quotes.length;
    return _quotes[index];
  }

  @override
  Future<List<Quote>> fetchQuotes({int count = 50}) async {
    return _quotes;
  }

  @override
  Future<void> clearCache() async {
    // No-op for fake service
  }
}
