import 'package:equatable/equatable.dart';

/// In-memory payload collected across the three quick-capture prompts.
class NfcQuickExpenseCaptureDraft extends Equatable {
  const NfcQuickExpenseCaptureDraft({
    this.amountCents,
    this.categoryId,
    this.note,
  });

  final int? amountCents;
  final String? categoryId;
  final String? note;

  NfcQuickExpenseCaptureDraft copyWith({
    int? amountCents,
    String? categoryId,
    String? note,
    bool clearNote = false,
  }) {
    return NfcQuickExpenseCaptureDraft(
      amountCents: amountCents ?? this.amountCents,
      categoryId: categoryId ?? this.categoryId,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  bool get hasValidAmount => amountCents != null && amountCents! > 0;

  bool get hasCategory =>
      categoryId != null && categoryId!.trim().isNotEmpty;

  bool get isReadyToSave => hasValidAmount && hasCategory;

  @override
  List<Object?> get props => [amountCents, categoryId, note];
}
