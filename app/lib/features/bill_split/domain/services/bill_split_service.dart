import 'package:uuid/uuid.dart';
import '../models/bill_split_models.dart';
import '../models/split_result.dart';

/// Service for bill splitting logic
abstract class BillSplitService {
  /// Create a bill from extracted data
  Bill createBill({
    String? vendor,
    required DateTime date,
    required List<BillItem> items,
    int taxPaise = 0,
    int tipPaise = 0,
    String? rawText,
  });

  /// Create a bill with just total amount (no items)
  Bill createSimpleBill({
    String? vendor,
    required DateTime date,
    required int totalPaise,
    int taxPaise = 0,
    int tipPaise = 0,
  });

  /// Split bill equally among participants
  SplitResult splitEqually({
    required Bill bill,
    required List<Participant> participants,
    String? note,
  });

  /// Split bill with custom options (who paid, split type)
  SplitResult splitWithOptions({
    required Bill bill,
    required List<Participant> participants,
    required PaidBy paidBy,
    required SplitOption splitOption,
    String? note,
  });

  /// Calculate per-person share for equal split
  int calculateEqualShare(int totalPaise, int participantCount);
}

/// Default implementation of BillSplitService
class BillSplitServiceImpl implements BillSplitService {
  final _uuid = const Uuid();

  @override
  Bill createBill({
    String? vendor,
    required DateTime date,
    required List<BillItem> items,
    int taxPaise = 0,
    int tipPaise = 0,
    String? rawText,
  }) {
    // Calculate subtotal from items
    final subtotalPaise = items.fold<int>(
      0,
      (sum, item) => sum + item.totalPaise,
    );

    // Total = subtotal + tax + tip
    final totalPaise = subtotalPaise + taxPaise + tipPaise;

    return Bill(
      id: _uuid.v4(),
      vendor: vendor,
      date: date,
      items: items,
      subtotalPaise: subtotalPaise,
      taxPaise: taxPaise,
      tipPaise: tipPaise,
      totalPaise: totalPaise,
      rawText: rawText,
      createdAt: DateTime.now(),
    );
  }

  @override
  Bill createSimpleBill({
    String? vendor,
    required DateTime date,
    required int totalPaise,
    int taxPaise = 0,
    int tipPaise = 0,
  }) {
    return Bill(
      id: _uuid.v4(),
      vendor: vendor,
      date: date,
      items: const [],
      subtotalPaise: totalPaise - taxPaise - tipPaise,
      taxPaise: taxPaise,
      tipPaise: tipPaise,
      totalPaise: totalPaise,
      createdAt: DateTime.now(),
    );
  }

  @override
  SplitResult splitEqually({
    required Bill bill,
    required List<Participant> participants,
    String? note,
  }) {
    if (participants.isEmpty) {
      throw ArgumentError('At least one participant is required');
    }

    final perPersonShare = calculateEqualShare(
      bill.totalPaise,
      participants.length,
    );

    // Handle remainder (give extra paise to first participants)
    final remainder = bill.totalPaise % participants.length;

    final splits = <ParticipantSplit>[];

    for (var i = 0; i < participants.length; i++) {
      // First 'remainder' participants get 1 extra paise
      final extraPaise = i < remainder ? 1 : 0;

      splits.add(
        ParticipantSplit(
          participant: participants[i],
          amountPaise: perPersonShare + extraPaise,
          currency: bill.currency,
        ),
      );
    }

    return SplitResult(
      id: _uuid.v4(),
      bill: bill,
      splits: splits,
      splitType: SplitType.equal,
      createdAt: DateTime.now(),
      note: note,
    );
  }

  @override
  SplitResult splitWithOptions({
    required Bill bill,
    required List<Participant> participants,
    required PaidBy paidBy,
    required SplitOption splitOption,
    String? note,
  }) {
    if (participants.isEmpty) {
      throw ArgumentError('At least one participant is required');
    }

    final splits = <ParticipantSplit>[];

    switch (splitOption) {
      case SplitOption.equalSplit:
        // Equal split: everyone pays their share (including "you")
        // Total participants = friends + 1 (you)
        final totalParticipants = participants.length + 1;
        final perPersonShare = calculateEqualShare(
          bill.totalPaise,
          totalParticipants,
        );
        final remainder = bill.totalPaise % totalParticipants;

        for (var i = 0; i < participants.length; i++) {
          final extraPaise = i < remainder ? 1 : 0;
          splits.add(
            ParticipantSplit(
              participant: participants[i],
              amountPaise: perPersonShare + extraPaise,
              currency: bill.currency,
            ),
          );
        }
        break;

      case SplitOption.youOweAll:
        // You owe the full amount - friend(s) don't owe anything
        // This means friend paid, you owe them
        for (final participant in participants) {
          splits.add(
            ParticipantSplit(
              participant: participant,
              amountPaise: 0,
              currency: bill.currency,
            ),
          );
        }
        break;

      case SplitOption.theyOweAll:
        // They owe the full amount - split among friends
        // This means you paid, they owe you
        if (participants.length == 1) {
          splits.add(
            ParticipantSplit(
              participant: participants.first,
              amountPaise: bill.totalPaise,
              currency: bill.currency,
            ),
          );
        } else {
          final perPersonShare = calculateEqualShare(
            bill.totalPaise,
            participants.length,
          );
          final remainder = bill.totalPaise % participants.length;

          for (var i = 0; i < participants.length; i++) {
            final extraPaise = i < remainder ? 1 : 0;
            splits.add(
              ParticipantSplit(
                participant: participants[i],
                amountPaise: perPersonShare + extraPaise,
                currency: bill.currency,
              ),
            );
          }
        }
        break;
    }

    return SplitResult(
      id: _uuid.v4(),
      bill: bill,
      splits: splits,
      splitType: SplitType.equal,
      paidBy: paidBy,
      splitOption: splitOption,
      createdAt: DateTime.now(),
      note: note,
    );
  }

  @override
  int calculateEqualShare(int totalPaise, int participantCount) {
    if (participantCount <= 0) {
      throw ArgumentError('Participant count must be positive');
    }
    return totalPaise ~/ participantCount;
  }
}
