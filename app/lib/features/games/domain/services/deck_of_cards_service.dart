import 'package:dio/dio.dart';
import '../models/card_model.dart';

/// Service to interact with Deck of Cards API
/// API Documentation: https://deckofcardsapi.com/
class DeckOfCardsService {
  static const String _baseUrl = 'https://deckofcardsapi.com/api/deck';
  final Dio _dio;

  DeckOfCardsService({Dio? dio}) : _dio = dio ?? Dio();

  /// Create and shuffle a new deck
  /// [deckCount] - Number of decks to use (default: 1, Blackjack uses 6)
  /// [jokers] - Include jokers in the deck
  Future<DeckResponse> createShuffledDeck({
    int deckCount = 1,
    bool jokers = false,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/new/shuffle/',
        queryParameters: {
          'deck_count': deckCount,
          if (jokers) 'jokers_enabled': true,
        },
      );

      return DeckResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to create shuffled deck: $e');
    }
  }

  /// Create a partial deck with specific cards
  /// [cards] - List of card codes (e.g., ['AS', '2S', 'KH'])
  Future<DeckResponse> createPartialDeck({
    required List<String> cards,
    bool shuffle = true,
  }) async {
    try {
      final path = shuffle ? '$_baseUrl/new/shuffle/' : '$_baseUrl/new/';
      final response = await _dio.get(
        path,
        queryParameters: {
          'cards': cards.join(','),
        },
      );

      return DeckResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to create partial deck: $e');
    }
  }

  /// Draw cards from a deck
  /// [deckId] - The deck ID (use 'new' to create and draw in one request)
  /// [count] - Number of cards to draw
  Future<DrawResponse> drawCards({
    required String deckId,
    int count = 1,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/$deckId/draw/',
        queryParameters: {
          'count': count,
        },
      );

      return DrawResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to draw cards: $e');
    }
  }

  /// Reshuffle the deck
  /// [deckId] - The deck ID
  /// [remainingOnly] - Only shuffle remaining cards (leave drawn cards alone)
  Future<DeckResponse> reshuffleDeck({
    required String deckId,
    bool remainingOnly = false,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/$deckId/shuffle/',
        queryParameters: {
          if (remainingOnly) 'remaining': true,
        },
      );

      return DeckResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to reshuffle deck: $e');
    }
  }

  /// Add cards to a pile
  /// [deckId] - The deck ID
  /// [pileName] - Name of the pile (e.g., 'player1', 'discard')
  /// [cards] - List of card codes to add
  Future<PileResponse> addToPile({
    required String deckId,
    required String pileName,
    required List<String> cards,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/$deckId/pile/$pileName/add/',
        queryParameters: {
          'cards': cards.join(','),
        },
      );

      return PileResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to add to pile: $e');
    }
  }

  /// List cards in a pile
  /// [deckId] - The deck ID
  /// [pileName] - Name of the pile
  Future<PileResponse> listPile({
    required String deckId,
    required String pileName,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/$deckId/pile/$pileName/list/',
      );

      return PileResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to list pile: $e');
    }
  }

  /// Draw cards from a pile
  /// [deckId] - The deck ID
  /// [pileName] - Name of the pile
  /// [cards] - Specific card codes to draw (optional)
  /// [count] - Number of cards to draw from top (optional)
  /// [position] - 'top', 'bottom', or 'random'
  Future<DrawResponse> drawFromPile({
    required String deckId,
    required String pileName,
    List<String>? cards,
    int? count,
    String position = 'top',
  }) async {
    try {
      String path = '$_baseUrl/$deckId/pile/$pileName/draw/';
      
      if (position == 'bottom') {
        path += 'bottom/';
      } else if (position == 'random') {
        path += 'random/';
      }

      final response = await _dio.get(
        path,
        queryParameters: {
          if (cards != null) 'cards': cards.join(','),
          if (count != null) 'count': count,
        },
      );

      return DrawResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to draw from pile: $e');
    }
  }

  /// Shuffle a pile
  /// [deckId] - The deck ID
  /// [pileName] - Name of the pile
  Future<PileResponse> shufflePile({
    required String deckId,
    required String pileName,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/$deckId/pile/$pileName/shuffle/',
      );

      return PileResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to shuffle pile: $e');
    }
  }

  /// Return cards to the deck
  /// [deckId] - The deck ID
  /// [cards] - Specific card codes to return (optional, returns all if null)
  Future<DeckResponse> returnCards({
    required String deckId,
    List<String>? cards,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/$deckId/return/',
        queryParameters: {
          if (cards != null) 'cards': cards.join(','),
        },
      );

      return DeckResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to return cards: $e');
    }
  }

  /// Return cards from a pile to the deck
  /// [deckId] - The deck ID
  /// [pileName] - Name of the pile
  /// [cards] - Specific card codes to return (optional)
  Future<DeckResponse> returnFromPile({
    required String deckId,
    required String pileName,
    List<String>? cards,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/$deckId/pile/$pileName/return/',
        queryParameters: {
          if (cards != null) 'cards': cards.join(','),
        },
      );

      return DeckResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to return from pile: $e');
    }
  }

  /// Get the back of card image URL
  static String get cardBackImage => 'https://deckofcardsapi.com/static/img/back.png';
}

