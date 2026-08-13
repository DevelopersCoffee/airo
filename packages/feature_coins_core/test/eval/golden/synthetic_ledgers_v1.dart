import 'package:feature_coins_core/src/entities/transaction.dart';

Transaction _tx({
  required String id,
  required String description,
  required int amountCents,
  required DateTime date,
  TransactionType type = TransactionType.expense,
}) {
  return Transaction(
    id: id,
    description: description,
    amountCents: amountCents,
    type: type,
    categoryId: 'cat-eval',
    accountId: 'acct-eval',
    transactionDate: date,
    createdAt: date,
  );
}

/// One single-merchant scenario: the transactions a real ledger might hold
/// for that merchant, and whether a human would call it a subscription.
class LedgerGoldenCase {
  final String name;
  final List<Transaction> transactions;
  final bool expectSubscription;

  const LedgerGoldenCase({
    required this.name,
    required this.transactions,
    required this.expectSubscription,
  });
}

/// Golden set v1 for COINS-AI-6 (recurrence/anomaly detection) and
/// COINS-AI-7 (this harness). 10 cases -- positives, negatives, and the
/// false-positive traps #1649's acceptance criteria named explicitly.
/// Distinct from the unit tests in recurrence_anomaly_detector_test.dart:
/// those assert individual behaviors, this is the versioned corpus a
/// scorecard is computed over.
final syntheticLedgersV1 = <LedgerGoldenCase>[
  LedgerGoldenCase(
    name: 'monthly streaming subscription',
    expectSubscription: true,
    transactions: [
      _tx(
        id: 'a1',
        description: 'Hotstar',
        amountCents: 29900,
        date: DateTime(2026, 1, 3),
      ),
      _tx(
        id: 'a2',
        description: 'Hotstar',
        amountCents: 29900,
        date: DateTime(2026, 2, 4),
      ),
      _tx(
        id: 'a3',
        description: 'Hotstar',
        amountCents: 29900,
        date: DateTime(2026, 3, 6),
      ),
      _tx(
        id: 'a4',
        description: 'Hotstar',
        amountCents: 29900,
        date: DateTime(2026, 4, 3),
      ),
    ],
  ),
  LedgerGoldenCase(
    name: 'annual insurance premium',
    expectSubscription: true,
    transactions: [
      _tx(
        id: 'b1',
        description: 'HDFC Life Premium',
        amountCents: 1200000,
        date: DateTime(2024, 3, 15),
      ),
      _tx(
        id: 'b2',
        description: 'HDFC Life Premium',
        amountCents: 1200000,
        date: DateTime(2025, 3, 18),
      ),
      _tx(
        id: 'b3',
        description: 'HDFC Life Premium',
        amountCents: 1200000,
        date: DateTime(2026, 3, 12),
      ),
    ],
  ),
  LedgerGoldenCase(
    name: 'gym membership with one price hike',
    expectSubscription: true,
    transactions: [
      _tx(
        id: 'c1',
        description: 'Cult Fit',
        amountCents: 150000,
        date: DateTime(2026, 1, 1),
      ),
      _tx(
        id: 'c2',
        description: 'Cult Fit',
        amountCents: 150000,
        date: DateTime(2026, 2, 1),
      ),
      _tx(
        id: 'c3',
        description: 'Cult Fit',
        amountCents: 175000,
        date: DateTime(2026, 3, 1),
      ),
      _tx(
        id: 'c4',
        description: 'Cult Fit',
        amountCents: 175000,
        date: DateTime(2026, 4, 1),
      ),
    ],
  ),
  LedgerGoldenCase(
    name: 'false positive trap: weekly farmers market, variable spend',
    expectSubscription: false,
    transactions: [
      _tx(
        id: 'd1',
        description: 'Farmers Market',
        amountCents: 1200,
        date: DateTime(2026, 1, 3),
      ),
      _tx(
        id: 'd2',
        description: 'Farmers Market',
        amountCents: 4500,
        date: DateTime(2026, 1, 10),
      ),
      _tx(
        id: 'd3',
        description: 'Farmers Market',
        amountCents: 900,
        date: DateTime(2026, 1, 17),
      ),
      _tx(
        id: 'd4',
        description: 'Farmers Market',
        amountCents: 6200,
        date: DateTime(2026, 1, 24),
      ),
    ],
  ),
  LedgerGoldenCase(
    name: 'false positive trap: same amount, no cadence',
    expectSubscription: false,
    transactions: [
      _tx(
        id: 'e1',
        description: 'Bookstore',
        amountCents: 2000,
        date: DateTime(2026, 1, 2),
      ),
      _tx(
        id: 'e2',
        description: 'Bookstore',
        amountCents: 2000,
        date: DateTime(2026, 1, 30),
      ),
      _tx(
        id: 'e3',
        description: 'Bookstore',
        amountCents: 2000,
        date: DateTime(2026, 5, 6),
      ),
      _tx(
        id: 'e4',
        description: 'Bookstore',
        amountCents: 2000,
        date: DateTime(2026, 5, 8),
      ),
    ],
  ),
  LedgerGoldenCase(
    name: 'too few occurrences to call it a pattern',
    expectSubscription: false,
    transactions: [
      _tx(
        id: 'f1',
        description: 'One-Off Vendor',
        amountCents: 5000,
        date: DateTime(2026, 1, 1),
      ),
      _tx(
        id: 'f2',
        description: 'One-Off Vendor',
        amountCents: 5000,
        date: DateTime(2026, 2, 1),
      ),
    ],
  ),
  LedgerGoldenCase(
    name: 'a single purchase is never a subscription',
    expectSubscription: false,
    transactions: [
      _tx(
        id: 'g1',
        description: 'Furniture Store',
        amountCents: 800000,
        date: DateTime(2026, 1, 1),
      ),
    ],
  ),
  LedgerGoldenCase(
    name: 'income is never a subscription',
    expectSubscription: false,
    transactions: [
      _tx(
        id: 'h1',
        description: 'Freelance Payment',
        amountCents: 500000,
        date: DateTime(2026, 1, 1),
        type: TransactionType.income,
      ),
      _tx(
        id: 'h2',
        description: 'Freelance Payment',
        amountCents: 500000,
        date: DateTime(2026, 2, 1),
        type: TransactionType.income,
      ),
      _tx(
        id: 'h3',
        description: 'Freelance Payment',
        amountCents: 500000,
        date: DateTime(2026, 3, 1),
        type: TransactionType.income,
      ),
    ],
  ),
  LedgerGoldenCase(
    name: 'quarterly software license',
    expectSubscription: true,
    transactions: [
      _tx(
        id: 'i1',
        description: 'Figma Team Plan',
        amountCents: 450000,
        date: DateTime(2026, 1, 5),
      ),
      _tx(
        id: 'i2',
        description: 'Figma Team Plan',
        amountCents: 450000,
        date: DateTime(2026, 4, 2),
      ),
      _tx(
        id: 'i3',
        description: 'Figma Team Plan',
        amountCents: 450000,
        date: DateTime(2026, 6, 30),
      ),
    ],
  ),
  LedgerGoldenCase(
    name: 'weekly meal kit',
    expectSubscription: true,
    transactions: [
      _tx(
        id: 'j1',
        description: 'FreshBox Meal Kit',
        amountCents: 89900,
        date: DateTime(2026, 1, 5),
      ),
      _tx(
        id: 'j2',
        description: 'FreshBox Meal Kit',
        amountCents: 89900,
        date: DateTime(2026, 1, 12),
      ),
      _tx(
        id: 'j3',
        description: 'FreshBox Meal Kit',
        amountCents: 89900,
        date: DateTime(2026, 1, 19),
      ),
      _tx(
        id: 'j4',
        description: 'FreshBox Meal Kit',
        amountCents: 89900,
        date: DateTime(2026, 1, 26),
      ),
    ],
  ),
];
