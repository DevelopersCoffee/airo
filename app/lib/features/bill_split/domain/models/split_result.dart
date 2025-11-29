import 'package:equatable/equatable.dart';
import 'bill_split_models.dart';

/// Who paid for the bill
enum PaidBy {
  you('You paid'),
  friend('Friend paid'),
  multiple('Multiple people');

  final String displayName;
  const PaidBy(this.displayName);
}

/// How to split the bill
enum SplitOption {
  equalSplit('Split equally'),
  youOweAll('You owe the full amount'),
  theyOweAll('They owe the full amount');

  final String displayName;
  const SplitOption(this.displayName);
}

/// Split type enum (legacy, kept for compatibility)
enum SplitType {
  equal('Equal Split'),
  percentage('By Percentage'),
  itemized('By Items');

  final String displayName;
  const SplitType(this.displayName);
}

/// Complete split result
class SplitResult extends Equatable {
  final String id;
  final Bill bill;
  final List<ParticipantSplit> splits;
  final SplitType splitType;
  final PaidBy paidBy;
  final SplitOption splitOption;
  final DateTime createdAt;
  final String? note;

  const SplitResult({
    required this.id,
    required this.bill,
    required this.splits,
    this.splitType = SplitType.equal,
    this.paidBy = PaidBy.you,
    this.splitOption = SplitOption.equalSplit,
    required this.createdAt,
    this.note,
  });

  /// Get total split amount (should match bill total)
  int get totalSplitPaise => splits.fold(0, (sum, s) => sum + s.amountPaise);

  /// Check if splits are balanced
  bool get isBalanced => totalSplitPaise == bill.totalPaise;

  /// Get participant count
  int get participantCount => splits.length;

  /// Generate shareable message for a participant
  String generateShareMessage(ParticipantSplit split) {
    final buffer = StringBuffer();

    buffer.writeln('💰 Bill Split Request');
    buffer.writeln('');

    if (bill.vendor != null && bill.vendor!.isNotEmpty) {
      buffer.writeln('📍 ${bill.vendor}');
    }

    buffer.writeln('📅 ${_formatDate(bill.date)}');
    buffer.writeln('');
    buffer.writeln('Total Bill: ${bill.formattedTotal}');
    buffer.writeln('Split among: $participantCount people');
    buffer.writeln('');
    buffer.writeln('👤 ${split.participant.name}');
    buffer.writeln('💵 Your share: ${split.formattedAmount}');

    if (note != null && note!.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('📝 Note: $note');
    }

    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('Shared via Airo');

    return buffer.toString();
  }

  /// Generate summary message for all participants
  String generateSummaryMessage() {
    final buffer = StringBuffer();

    buffer.writeln('💰 Bill Split Summary');
    buffer.writeln('');

    if (bill.vendor != null && bill.vendor!.isNotEmpty) {
      buffer.writeln('📍 ${bill.vendor}');
    }

    buffer.writeln('📅 ${_formatDate(bill.date)}');
    buffer.writeln('');
    buffer.writeln('Total: ${bill.formattedTotal}');
    buffer.writeln('Split: ${splitType.displayName}');
    buffer.writeln('');
    buffer.writeln('Breakdown:');

    for (final split in splits) {
      buffer.writeln('• ${split.participant.name}: ${split.formattedAmount}');
    }

    if (note != null && note!.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('📝 $note');
    }

    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('Shared via Airo');

    return buffer.toString();
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  List<Object?> get props => [
    id,
    bill,
    splits,
    splitType,
    paidBy,
    splitOption,
    createdAt,
    note,
  ];
}
