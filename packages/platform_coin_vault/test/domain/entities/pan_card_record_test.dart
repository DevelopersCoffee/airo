import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/domain/entities/pan_card_record.dart';

void main() {
  group('PanCardRecord', () {
    test('constructs with a valid PAN number', () {
      final record = PanCardRecord(
        id: null,
        panNumber: 'ABCDE1234F',
        nameOnCard: 'Jane Doe',
      );

      expect(record.panNumber, 'ABCDE1234F');
    });

    test('throws ArgumentError for an invalid PAN number', () {
      expect(
        () => PanCardRecord(
          id: null,
          panNumber: 'not-a-pan',
          nameOnCard: 'Jane Doe',
        ),
        throwsArgumentError,
      );
    });

    test('two records with identical fields are equal', () {
      final a = PanCardRecord(
        id: 1,
        panNumber: 'ABCDE1234F',
        nameOnCard: 'Jane Doe',
        createdAt: DateTime(2026, 7, 19),
      );
      final b = PanCardRecord(
        id: 1,
        panNumber: 'ABCDE1234F',
        nameOnCard: 'Jane Doe',
        createdAt: DateTime(2026, 7, 19),
      );

      expect(a, equals(b));
    });
  });
}
