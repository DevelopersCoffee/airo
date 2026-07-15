import 'dart:convert';

import 'package:airo_app/features/quotes/application/providers/quote_provider.dart';
import 'package:airo_app/features/quotes/domain/models/quote_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('QuotePreferencesNotifier', () {
    test('loads saved quote preferences', () async {
      SharedPreferences.setMockInitialValues({
        'quote_preferences': jsonEncode(
          const QuotePreferences(
            showQuotes: false,
            quoteSource: 'zenquotes',
          ).toJson(),
        ),
      });

      final notifier = QuotePreferencesNotifier();
      await pumpEventQueue();

      expect(notifier.state.showQuotes, isFalse);
      expect(notifier.state.quoteSource, 'zenquotes');
    });

    test('persists quote preferences through guarded store', () async {
      SharedPreferences.setMockInitialValues({});

      final notifier = QuotePreferencesNotifier();
      await pumpEventQueue();

      await notifier.setQuoteSource('lifeHacks');
      await notifier.setShowQuotes(false);

      final prefs = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(prefs.getString('quote_preferences')!)
              as Map<String, dynamic>;
      expect(saved['quoteSource'], 'lifeHacks');
      expect(saved['showQuotes'], isFalse);
    });

    test(
      'does not overwrite preferences when payload exceeds prefs tier',
      () async {
        final original = jsonEncode(
          const QuotePreferences(
            showQuotes: true,
            quoteSource: 'fake',
          ).toJson(),
        );
        SharedPreferences.setMockInitialValues({'quote_preferences': original});

        final notifier = QuotePreferencesNotifier(maxPreferenceValueBytes: 64);
        await pumpEventQueue();

        await notifier.setQuoteSource('source-${List.filled(256, 'x').join()}');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('quote_preferences'), original);
        expect(notifier.state.quoteSource, startsWith('source-'));
      },
    );
  });
}
