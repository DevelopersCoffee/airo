import 'package:feature_coins_core/src/entities/transaction.dart';
import 'package:feature_coins_core/src/models/recurrence_cycle.dart';
import 'package:feature_coins_core/src/models/spending_anomaly.dart';
import 'package:feature_coins_core/src/services/recurrence_anomaly_detector.dart';
import 'package:test/test.dart';

Transaction _tx({
  required String id,
  required String description,
  required int amountCents,
  required DateTime date,
}) {
  return Transaction(
    id: id,
    description: description,
    amountCents: amountCents,
    type: TransactionType.expense,
    categoryId: 'cat-subscriptions',
    accountId: 'acct-1',
    transactionDate: date,
    createdAt: date,
  );
}

void main() {
  group('RecurrenceAnomalyDetector.detectSubscriptions', () {
    const detector = RecurrenceAnomalyDetector();

    test('finds a monthly subscription with billing-date phase shift', () {
      // Netflix charges land a few days apart each cycle, not exactly 30
      // days -- a real billing calendar drifts around weekends/month length.
      final txs = [
        _tx(
          id: '1',
          description: 'Netflix',
          amountCents: 64900,
          date: DateTime(2026, 1, 3),
        ),
        _tx(
          id: '2',
          description: 'Netflix',
          amountCents: 64900,
          date: DateTime(2026, 2, 5),
        ),
        _tx(
          id: '3',
          description: 'Netflix',
          amountCents: 64900,
          date: DateTime(2026, 3, 5),
        ),
        _tx(
          id: '4',
          description: 'Netflix',
          amountCents: 64900,
          date: DateTime(2026, 4, 8),
        ),
      ];

      final result = detector.detectSubscriptions(txs);

      expect(result, hasLength(1));
      expect(result.single.merchantKey, 'netflix');
      expect(result.single.cycle, RecurrenceCycle.monthly);
      expect(result.single.currentAmountCents, 64900);
      expect(result.single.occurrences, hasLength(4));
    });

    test('finds an annual subscription', () {
      final txs = [
        _tx(
          id: '1',
          description: 'Amazon Prime',
          amountCents: 149900,
          date: DateTime(2024, 6, 10),
        ),
        _tx(
          id: '2',
          description: 'Amazon Prime',
          amountCents: 149900,
          date: DateTime(2025, 6, 12),
        ),
        _tx(
          id: '3',
          description: 'Amazon Prime',
          amountCents: 149900,
          date: DateTime(2026, 6, 8),
        ),
      ];

      final result = detector.detectSubscriptions(txs);

      expect(result, hasLength(1));
      expect(result.single.cycle, RecurrenceCycle.yearly);
    });

    test('recognizes a subscription through one price change', () {
      final txs = [
        _tx(
          id: '1',
          description: 'Spotify',
          amountCents: 11900,
          date: DateTime(2026, 1, 15),
        ),
        _tx(
          id: '2',
          description: 'Spotify',
          amountCents: 11900,
          date: DateTime(2026, 2, 15),
        ),
        _tx(
          id: '3',
          // ~26% price hike -- a real Spotify-style increase, not noise.
          description: 'Spotify',
          amountCents: 14900,
          date: DateTime(2026, 3, 15),
        ),
        _tx(
          id: '4',
          description: 'Spotify',
          amountCents: 14900,
          date: DateTime(2026, 4, 15),
        ),
      ];

      final result = detector.detectSubscriptions(txs);

      expect(result, hasLength(1));
      expect(result.single.currentAmountCents, 14900);
    });

    test(
      'false-positive trap: a monthly grocery run is not a subscription',
      () {
        // Same merchant, roughly monthly cadence, but wildly different
        // totals each time -- exactly what a subscription is not.
        final txs = [
          _tx(
            id: '1',
            description: 'Whole Foods',
            amountCents: 4200,
            date: DateTime(2026, 1, 4),
          ),
          _tx(
            id: '2',
            description: 'Whole Foods',
            amountCents: 18700,
            date: DateTime(2026, 2, 3),
          ),
          _tx(
            id: '3',
            description: 'Whole Foods',
            amountCents: 6100,
            date: DateTime(2026, 3, 5),
          ),
          _tx(
            id: '4',
            description: 'Whole Foods',
            amountCents: 25400,
            date: DateTime(2026, 4, 2),
          ),
        ];

        final result = detector.detectSubscriptions(txs);

        expect(result, isEmpty);
      },
    );

    test(
      'false-positive trap: irregular gaps do not cluster into a cycle',
      () {
        final txs = [
          _tx(
            id: '1',
            description: 'Corner Cafe',
            amountCents: 500,
            date: DateTime(2026, 1, 1),
          ),
          _tx(
            id: '2',
            description: 'Corner Cafe',
            amountCents: 500,
            date: DateTime(2026, 1, 4),
          ),
          _tx(
            id: '3',
            description: 'Corner Cafe',
            amountCents: 500,
            date: DateTime(2026, 2, 20),
          ),
          _tx(
            id: '4',
            description: 'Corner Cafe',
            amountCents: 500,
            date: DateTime(2026, 2, 21),
          ),
        ];

        final result = detector.detectSubscriptions(txs);

        expect(result, isEmpty);
      },
    );

    test('requires at least 3 occurrences -- two points always "cluster"', () {
      final txs = [
        _tx(
          id: '1',
          description: 'Random Store',
          amountCents: 5000,
          date: DateTime(2026, 1, 1),
        ),
        _tx(
          id: '2',
          description: 'Random Store',
          amountCents: 5000,
          date: DateTime(2026, 2, 1),
        ),
      ];

      final result = detector.detectSubscriptions(txs);

      expect(result, isEmpty);
    });

    test('ignores income and deleted transactions', () {
      final txs = [
        _tx(
          id: '1',
          description: 'Salary',
          amountCents: 500000,
          date: DateTime(2026, 1, 1),
        ).copyWith(type: TransactionType.income),
        _tx(
          id: '2',
          description: 'Salary',
          amountCents: 500000,
          date: DateTime(2026, 2, 1),
        ).copyWith(type: TransactionType.income),
        _tx(
          id: '3',
          description: 'Salary',
          amountCents: 500000,
          date: DateTime(2026, 3, 1),
        ).copyWith(type: TransactionType.income),
        _tx(
          id: '4',
          description: 'Ghost Charge',
          amountCents: 999,
          date: DateTime(2026, 1, 1),
        ).copyWith(isDeleted: true),
        _tx(
          id: '5',
          description: 'Ghost Charge',
          amountCents: 999,
          date: DateTime(2026, 2, 1),
        ).copyWith(isDeleted: true),
        _tx(
          id: '6',
          description: 'Ghost Charge',
          amountCents: 999,
          date: DateTime(2026, 3, 1),
        ).copyWith(isDeleted: true),
      ];

      final result = detector.detectSubscriptions(txs);

      expect(result, isEmpty);
    });

    test('merchant grouping is case- and whitespace-insensitive', () {
      final txs = [
        _tx(
          id: '1',
          description: '  Netflix  ',
          amountCents: 64900,
          date: DateTime(2026, 1, 3),
        ),
        _tx(
          id: '2',
          description: 'NETFLIX',
          amountCents: 64900,
          date: DateTime(2026, 2, 3),
        ),
        _tx(
          id: '3',
          description: 'netflix',
          amountCents: 64900,
          date: DateTime(2026, 3, 3),
        ),
      ];

      final result = detector.detectSubscriptions(txs);

      expect(result, hasLength(1));
      expect(result.single.occurrences, hasLength(3));
    });
  });

  group('RecurrenceAnomalyDetector.detectAnomalies', () {
    const detector = RecurrenceAnomalyDetector();

    test('flags a price increase on a detected subscription', () {
      final txs = [
        _tx(
          id: '1',
          description: 'Spotify',
          amountCents: 11900,
          date: DateTime(2026, 1, 15),
        ),
        _tx(
          id: '2',
          description: 'Spotify',
          amountCents: 11900,
          date: DateTime(2026, 2, 15),
        ),
        _tx(
          id: '3',
          description: 'Spotify',
          amountCents: 14900,
          date: DateTime(2026, 3, 15),
        ),
      ];

      final anomalies = detector.detectAnomalies(txs);

      expect(anomalies, hasLength(1));
      final anomaly = anomalies.single;
      expect(anomaly.type, SpendingAnomalyType.priceIncrease);
      expect(anomaly.transaction.id, '3');
      expect(anomaly.previousAmountCents, 11900);
      expect(anomaly.deltaCents, 3000);
    });

    test('flags a price decrease on a detected subscription', () {
      final txs = [
        _tx(
          id: '1',
          description: 'Gym Membership',
          amountCents: 20000,
          date: DateTime(2026, 1, 1),
        ),
        _tx(
          id: '2',
          description: 'Gym Membership',
          amountCents: 20000,
          date: DateTime(2026, 2, 1),
        ),
        _tx(
          id: '3',
          description: 'Gym Membership',
          amountCents: 15000,
          date: DateTime(2026, 3, 1),
        ),
      ];

      final anomalies = detector.detectAnomalies(txs);

      expect(anomalies, hasLength(1));
      expect(anomalies.single.type, SpendingAnomalyType.priceDecrease);
      expect(anomalies.single.deltaCents, -5000);
    });

    test('flags a new-merchant spike against the typical transaction size', () {
      final typical = List.generate(
        6,
        (i) => _tx(
          id: 'typical-$i',
          description: 'Coffee Shop',
          amountCents: 400,
          date: DateTime(2026, 1, i + 1),
        ),
      );
      final spike = _tx(
        id: 'spike',
        description: 'Luxury Watch Boutique',
        amountCents: 500000,
        date: DateTime(2026, 1, 20),
      );

      final anomalies = detector.detectAnomalies([...typical, spike]);

      expect(
        anomalies.where((a) => a.type == SpendingAnomalyType.newMerchantSpike),
        hasLength(1),
      );
      final anomaly = anomalies.firstWhere(
        (a) => a.type == SpendingAnomalyType.newMerchantSpike,
      );
      expect(anomaly.transaction.id, 'spike');
      expect(anomaly.previousAmountCents, isNull);
    });

    test('does not flag a new merchant priced near the typical spend', () {
      final typical = List.generate(
        6,
        (i) => _tx(
          id: 'typical-$i',
          description: 'Coffee Shop',
          amountCents: 400,
          date: DateTime(2026, 1, i + 1),
        ),
      );
      final normal = _tx(
        id: 'normal',
        description: 'Sandwich Place',
        amountCents: 550,
        date: DateTime(2026, 1, 20),
      );

      final anomalies = detector.detectAnomalies([...typical, normal]);

      expect(
        anomalies.where((a) => a.type == SpendingAnomalyType.newMerchantSpike),
        isEmpty,
      );
    });

    test('skips spike detection with too little transaction history', () {
      final txs = [
        _tx(
          id: '1',
          description: 'Coffee Shop',
          amountCents: 400,
          date: DateTime(2026, 1, 1),
        ),
        _tx(
          id: '2',
          description: 'Big One-Off',
          amountCents: 900000,
          date: DateTime(2026, 1, 2),
        ),
      ];

      final anomalies = detector.detectAnomalies(txs);

      expect(anomalies, isEmpty);
    });
  });
}
