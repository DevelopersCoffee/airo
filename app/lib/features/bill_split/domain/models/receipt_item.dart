import 'package:equatable/equatable.dart';

import '../../../../core/utils/currency_formatter.dart';

/// A participant in item splitting
class ItemParticipant extends Equatable {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isMe;

  const ItemParticipant({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isMe = false,
  });

  /// "Me" participant
  static const me = ItemParticipant(id: 'me', name: 'Me', isMe: true);

  @override
  List<Object?> get props => [id, name, avatarUrl, isMe];
}

/// A single item extracted from a receipt
class ReceiptItem extends Equatable {
  final String id;
  final String name;
  final int quantity;
  final int unitPricePaise;
  final int totalPricePaise;
  final Set<String> assignedParticipantIds; // Who pays for this item
  final String? category;

  const ReceiptItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    required this.unitPricePaise,
    required this.totalPricePaise,
    this.assignedParticipantIds = const {}, // Empty = split among all
    this.category,
  });

  /// Create a copy with updated assignments
  ReceiptItem copyWith({
    String? id,
    String? name,
    int? quantity,
    int? unitPricePaise,
    int? totalPricePaise,
    Set<String>? assignedParticipantIds,
    String? category,
  }) {
    return ReceiptItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPricePaise: unitPricePaise ?? this.unitPricePaise,
      totalPricePaise: totalPricePaise ?? this.totalPricePaise,
      assignedParticipantIds:
          assignedParticipantIds ?? this.assignedParticipantIds,
      category: category ?? this.category,
    );
  }

  /// Toggle a participant's assignment
  ReceiptItem toggleParticipant(String participantId) {
    final newSet = Set<String>.from(assignedParticipantIds);
    if (newSet.contains(participantId)) {
      newSet.remove(participantId);
    } else {
      newSet.add(participantId);
    }
    return copyWith(assignedParticipantIds: newSet);
  }

  /// Check if assigned to specific participant
  bool isAssignedTo(String participantId) =>
      assignedParticipantIds.contains(participantId);

  /// Check if split among all (no specific assignments)
  bool get isSplitAmongAll => assignedParticipantIds.isEmpty;

  // ---- Locale-aware formatting methods (preferred) ----

  /// Format total price using locale-aware CurrencyFormatter
  String formatPrice(CurrencyFormatter formatter) {
    return formatter.formatCents(totalPricePaise);
  }

  /// Format unit price using locale-aware CurrencyFormatter
  String formatUnitPrice(CurrencyFormatter formatter) {
    return formatter.formatCents(unitPricePaise);
  }

  // ---- Deprecated getters for backward compatibility ----

  /// Formatted price string
  @Deprecated('Use formatPrice(CurrencyFormatter) for global locale support')
  String get formattedPrice => '₹${(totalPricePaise / 100).toStringAsFixed(2)}';

  /// Formatted unit price
  @Deprecated(
    'Use formatUnitPrice(CurrencyFormatter) for global locale support',
  )
  String get formattedUnitPrice =>
      '₹${(unitPricePaise / 100).toStringAsFixed(2)}';

  @override
  List<Object?> get props => [
    id,
    name,
    quantity,
    unitPricePaise,
    totalPricePaise,
    assignedParticipantIds,
    category,
  ];
}

/// Fee types in a receipt
enum FeeType {
  delivery('Delivery Fee'),
  handling('Handling Fee'),
  packaging('Packaging Fee'),
  tax('Tax'),
  tip('Tip'),
  other('Other Fee');

  final String displayName;
  const FeeType(this.displayName);
}

/// A fee on the receipt (delivery, handling, etc.)
class ReceiptFee extends Equatable {
  final FeeType type;
  final int amountPaise;
  final bool isFree;

  const ReceiptFee({
    required this.type,
    required this.amountPaise,
    this.isFree = false,
  });

  /// Format amount using locale-aware CurrencyFormatter
  String formatAmount(CurrencyFormatter formatter) {
    return isFree ? 'Free' : formatter.formatCents(amountPaise);
  }

  /// @deprecated Use formatAmount(CurrencyFormatter) for global locale support
  @Deprecated('Use formatAmount(CurrencyFormatter) for global locale support')
  String get formattedAmount =>
      isFree ? 'Free' : '₹${(amountPaise / 100).toStringAsFixed(2)}';

  @override
  List<Object?> get props => [type, amountPaise, isFree];
}

/// A parsed receipt with items and fees
class ParsedReceipt extends Equatable {
  final String id;
  final String? vendor;
  final String? orderId;
  final DateTime? orderDate;
  final List<ReceiptItem> items;
  final List<ReceiptFee> fees;
  final int itemTotalPaise;
  final int grandTotalPaise;
  final String? imagePath;
  final DateTime parsedAt;

  const ParsedReceipt({
    required this.id,
    this.vendor,
    this.orderId,
    this.orderDate,
    required this.items,
    this.fees = const [],
    required this.itemTotalPaise,
    required this.grandTotalPaise,
    this.imagePath,
    required this.parsedAt,
  });

  /// Calculate totals for each participant
  /// Returns map of participantId -> amount in paise
  Map<String, int> calculateParticipantTotals(
    List<ItemParticipant> participants,
  ) {
    final totals = <String, int>{};
    for (final p in participants) {
      totals[p.id] = 0;
    }

    for (final item in items) {
      if (item.isSplitAmongAll) {
        // Split among all participants
        final share = item.totalPricePaise ~/ participants.length;
        final remainder = item.totalPricePaise % participants.length;
        for (var i = 0; i < participants.length; i++) {
          totals[participants[i].id] =
              (totals[participants[i].id] ?? 0) +
              share +
              (i < remainder ? 1 : 0);
        }
      } else {
        // Split among assigned participants only
        final assignedCount = item.assignedParticipantIds.length;
        if (assignedCount > 0) {
          final share = item.totalPricePaise ~/ assignedCount;
          final remainder = item.totalPricePaise % assignedCount;
          var i = 0;
          for (final pid in item.assignedParticipantIds) {
            totals[pid] = (totals[pid] ?? 0) + share + (i < remainder ? 1 : 0);
            i++;
          }
        }
      }
    }

    // Add fees proportionally
    final feesTotal = fees
        .where((f) => !f.isFree)
        .fold<int>(0, (sum, f) => sum + f.amountPaise);

    if (feesTotal > 0 && itemTotalPaise > 0) {
      for (final p in participants) {
        final ratio = (totals[p.id] ?? 0) / itemTotalPaise;
        totals[p.id] = (totals[p.id] ?? 0) + (feesTotal * ratio).round();
      }
    }

    return totals;
  }

  // ---- Locale-aware formatting methods (preferred) ----

  /// Format grand total using locale-aware CurrencyFormatter
  String formatGrandTotal(CurrencyFormatter formatter) {
    return formatter.formatCents(grandTotalPaise);
  }

  /// Format item total using locale-aware CurrencyFormatter
  String formatItemTotal(CurrencyFormatter formatter) {
    return formatter.formatCents(itemTotalPaise);
  }

  // ---- Deprecated getters for backward compatibility ----

  /// Get formatted grand total
  @Deprecated(
    'Use formatGrandTotal(CurrencyFormatter) for global locale support',
  )
  String get formattedGrandTotal =>
      '₹${(grandTotalPaise / 100).toStringAsFixed(2)}';

  /// Get formatted item total
  @Deprecated(
    'Use formatItemTotal(CurrencyFormatter) for global locale support',
  )
  String get formattedItemTotal =>
      '₹${(itemTotalPaise / 100).toStringAsFixed(2)}';

  @override
  List<Object?> get props => [
    id,
    vendor,
    orderId,
    orderDate,
    items,
    fees,
    itemTotalPaise,
    grandTotalPaise,
    imagePath,
    parsedAt,
  ];
}
