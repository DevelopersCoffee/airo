import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/bill_split_models.dart';
import '../../domain/models/split_result.dart';
import '../../domain/services/bill_split_service.dart';
import '../../domain/services/contact_service.dart';

// ============================================================================
// SERVICE PROVIDERS
// ============================================================================

/// Bill split service provider
final billSplitServiceProvider = Provider<BillSplitService>((ref) {
  return BillSplitServiceImpl();
});

/// Contact service provider (uses real device contacts on mobile)
final contactServiceProvider = Provider<ContactService>((ref) {
  return DeviceContactService();
});

// ============================================================================
// STATE PROVIDERS
// ============================================================================

/// Current bill being split
final currentBillProvider = StateProvider<Bill?>((ref) => null);

/// Selected participants for current split
final selectedParticipantsProvider = StateProvider<List<Participant>>(
  (ref) => [],
);

/// Current split result
final currentSplitResultProvider = StateProvider<SplitResult?>((ref) => null);

/// Split note
final splitNoteProvider = StateProvider<String?>((ref) => null);

// ============================================================================
// ASYNC PROVIDERS
// ============================================================================

/// All contacts provider
final contactsProvider = FutureProvider<List<Participant>>((ref) async {
  final contactService = ref.watch(contactServiceProvider);
  return await contactService.getContacts();
});

/// Recent contacts provider
final recentContactsProvider = FutureProvider<List<Participant>>((ref) async {
  final contactService = ref.watch(contactServiceProvider);
  return await contactService.getRecentContacts();
});

/// Search contacts provider
final searchContactsProvider = FutureProvider.family<List<Participant>, String>(
  (ref, query) async {
    if (query.isEmpty) {
      return await ref.watch(contactsProvider.future);
    }
    final contactService = ref.watch(contactServiceProvider);
    return await contactService.searchContacts(query);
  },
);

// ============================================================================
// CONTROLLER
// ============================================================================

/// Bill split controller provider
final billSplitControllerProvider = Provider<BillSplitController>((ref) {
  return BillSplitController(ref);
});

/// Controller for bill splitting operations
class BillSplitController {
  final Ref _ref;

  BillSplitController(this._ref);

  BillSplitService get _service => _ref.read(billSplitServiceProvider);

  /// Create a simple bill with just total amount
  void createSimpleBill({
    String? vendor,
    required DateTime date,
    required double totalAmount,
    double taxAmount = 0,
    double tipAmount = 0,
  }) {
    final bill = _service.createSimpleBill(
      vendor: vendor,
      date: date,
      totalPaise: (totalAmount * 100).round(),
      taxPaise: (taxAmount * 100).round(),
      tipPaise: (tipAmount * 100).round(),
    );
    _ref.read(currentBillProvider.notifier).state = bill;
  }

  /// Create a bill with items
  void createBillWithItems({
    String? vendor,
    required DateTime date,
    required List<BillItem> items,
    double taxAmount = 0,
    double tipAmount = 0,
    String? rawText,
  }) {
    final bill = _service.createBill(
      vendor: vendor,
      date: date,
      items: items,
      taxPaise: (taxAmount * 100).round(),
      tipPaise: (tipAmount * 100).round(),
      rawText: rawText,
    );
    _ref.read(currentBillProvider.notifier).state = bill;
  }

  /// Add a participant
  void addParticipant(Participant participant) {
    final current = _ref.read(selectedParticipantsProvider);
    if (!current.any((p) => p.id == participant.id)) {
      _ref.read(selectedParticipantsProvider.notifier).state = [
        ...current,
        participant,
      ];
    }
  }

  /// Remove a participant
  void removeParticipant(String participantId) {
    final current = _ref.read(selectedParticipantsProvider);
    _ref.read(selectedParticipantsProvider.notifier).state = current
        .where((p) => p.id != participantId)
        .toList();
  }

  /// Clear all participants
  void clearParticipants() {
    _ref.read(selectedParticipantsProvider.notifier).state = [];
  }

  /// Set split note
  void setNote(String? note) {
    _ref.read(splitNoteProvider.notifier).state = note;
  }

  /// Calculate and store split result (legacy - equal split only)
  SplitResult? calculateSplit() {
    return calculateSplitWithOptions(
      paidBy: PaidBy.you,
      splitOption: SplitOption.equalSplit,
    );
  }

  /// Calculate and store split result with custom options
  SplitResult? calculateSplitWithOptions({
    required PaidBy paidBy,
    required SplitOption splitOption,
  }) {
    final bill = _ref.read(currentBillProvider);
    final participants = _ref.read(selectedParticipantsProvider);
    final note = _ref.read(splitNoteProvider);

    if (bill == null || participants.isEmpty) {
      return null;
    }

    final result = _service.splitWithOptions(
      bill: bill,
      participants: participants,
      paidBy: paidBy,
      splitOption: splitOption,
      note: note,
    );

    _ref.read(currentSplitResultProvider.notifier).state = result;
    return result;
  }

  /// Reset all state
  void reset() {
    _ref.read(currentBillProvider.notifier).state = null;
    _ref.read(selectedParticipantsProvider.notifier).state = [];
    _ref.read(currentSplitResultProvider.notifier).state = null;
    _ref.read(splitNoteProvider.notifier).state = null;
  }
}
