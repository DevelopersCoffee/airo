import 'package:airo_app/features/quotes/domain/services/quote_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ZenQuotesService', () {
    test('caches fetched quotes through guarded preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = ZenQuotesService(
        dio: _dioReturning([
          {'q': 'Small steps compound.', 'a': 'Airo'},
        ]),
        prefs: prefs,
      );

      final quotes = await service.fetchQuotes();

      expect(quotes, hasLength(1));
      expect(quotes.single.text, 'Small steps compound.');
      expect(prefs.getString('cached_quotes'), isNotNull);
      expect(prefs.getString('quotes_last_fetch'), isNotNull);
    });

    test('drops oversized quote cache before raw persistence', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = ZenQuotesService(
        dio: _dioReturning([
          {'q': 'quote ${List.filled(512, 'x').join()}', 'a': 'Oversized'},
        ]),
        prefs: prefs,
        maxPreferenceValueBytes: 128,
      );

      final quotes = await service.fetchQuotes();

      expect(quotes, hasLength(1));
      expect(prefs.getString('cached_quotes'), isNull);
      expect(prefs.getString('quotes_last_fetch'), isNull);
    });

    test('clears cached quote keys through guarded preferences', () async {
      SharedPreferences.setMockInitialValues({
        'cached_quotes': '[{"q":"Hello","a":"Airo"}]',
        'quotes_last_fetch': DateTime.utc(2026).toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ZenQuotesService(dio: _dioReturning([]), prefs: prefs);

      await service.clearCache();

      expect(prefs.getString('cached_quotes'), isNull);
      expect(prefs.getString('quotes_last_fetch'), isNull);
    });
  });
}

Dio _dioReturning(List<Map<String, dynamic>> quotes) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<List<Map<String, dynamic>>>(
            requestOptions: options,
            statusCode: 200,
            data: quotes,
          ),
        );
      },
    ),
  );
  return dio;
}
