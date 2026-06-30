import 'package:dio/dio.dart';
import '../models/dictionary_entry.dart';

/// Service to fetch word definitions from Free Dictionary API
class DictionaryService {
  static const String _baseUrl =
      'https://api.dictionaryapi.dev/api/v2/entries/en';

  final Dio _dio;

  DictionaryService({Dio? dio}) : _dio = dio ?? Dio();

  /// Look up a word and get its definitions
  ///
  /// Returns a list of dictionary entries (usually just one, but some words
  /// may have multiple entries)
  ///
  /// Throws [DictionaryNotFoundException] if word is not found
  /// Throws [DictionaryServiceException] for other errors
  Future<List<DictionaryEntry>> lookupWord(String word) async {
    try {
      // Clean the word (trim, lowercase)
      final cleanWord = word.trim().toLowerCase();

      if (cleanWord.isEmpty) {
        throw DictionaryServiceException('Word cannot be empty');
      }

      final response = await _dio.get(
        '$_baseUrl/$cleanWord',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map(
              (json) => DictionaryEntry.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw DictionaryServiceException(
          'Failed to fetch definition: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw DictionaryNotFoundException('Word "$word" not found');
      }
      throw DictionaryServiceException(
        'Network error: ${e.message}',
        originalError: e,
      );
    } catch (e) {
      if (e is DictionaryServiceException) rethrow;
      throw DictionaryServiceException(
        'Unexpected error: $e',
        originalError: e,
      );
    }
  }

  /// Get the first definition for a word (most common use case)
  Future<DictionaryEntry?> getFirstDefinition(String word) async {
    try {
      final entries = await lookupWord(word);
      return entries.isNotEmpty ? entries.first : null;
    } catch (e) {
      return null;
    }
  }

  /// Check if a word exists in the dictionary
  Future<bool> wordExists(String word) async {
    try {
      await lookupWord(word);
      return true;
    } on DictionaryNotFoundException {
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// Base exception for dictionary service
class DictionaryServiceException implements Exception {
  final String message;
  final Object? originalError;

  DictionaryServiceException(this.message, {this.originalError});

  @override
  String toString() => 'DictionaryServiceException: $message';
}

/// Exception thrown when a word is not found
class DictionaryNotFoundException extends DictionaryServiceException {
  DictionaryNotFoundException(super.message);

  @override
  String toString() => 'DictionaryNotFoundException: $message';
}
