import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/repositories/settlement_repository.dart';
import '../../domain/services/balance_engine.dart';
import '../../domain/services/debt_simplifier.dart';
import '../../domain/models/balance_summary.dart';
import 'group_providers.dart';

/// Settlement repository provider
///
/// Must be overridden in main.dart with actual implementation.
///
/// Phase: 2 (Split Engine)
final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  throw UnimplementedError(
    'settlementRepositoryProvider must be overridden in main.dart',
  );
});

/// Balance engine provider
final balanceEngineProvider = Provider<BalanceEngine>((ref) {
  return BalanceEngineImpl();
});

/// Debt simplifier provider
final debtSimplifierProvider = Provider<DebtSimplifier>((ref) {
  return DebtSimplifierImpl();
});

/// Watch settlements for a group
final groupSettlementsProvider =
    StreamProvider.family<List<Settlement>, String>((ref, groupId) {
  final repo = ref.watch(settlementRepositoryProvider);
  return repo.watchByGroup(groupId);
});

/// Watch pending settlements for current user
final pendingSettlementsProvider = StreamProvider<List<Settlement>>((ref) {
  // TODO: Get current user ID from auth
  const currentUserId = 'current_user_id';
  final repo = ref.watch(settlementRepositoryProvider);
  return repo.watchPendingForUser(currentUserId);
});

/// Balance summary for a group
final groupBalanceSummaryProvider =
    FutureProvider.family<BalanceSummary, String>((ref, groupId) async {
  final groupRepo = ref.watch(groupRepositoryProvider);
  final settlementRepo = ref.watch(settlementRepositoryProvider);
  final engine = ref.watch(balanceEngineProvider);

  final expensesResult = await groupRepo.getExpenses(groupId);
  final settlementsResult = await settlementRepo.findByGroup(groupId);

  return engine.calculateBalanceSummary(
    groupId: groupId,
    expenses: expensesResult.data ?? [],
    settlements: settlementsResult.data ?? [],
  );
});

/// Simplified debts for a group
final simplifiedDebtsProvider = FutureProvider.family<BalanceSummary, String>(
  (ref, groupId) async {
    final summary = await ref.watch(groupBalanceSummaryProvider(groupId).future);
    final simplifier = ref.watch(debtSimplifierProvider);

    final simplifiedDebts = simplifier.fromNetBalances(summary.netBalances);

    return summary.copyWith(simplifiedDebts: simplifiedDebts);
  },
);

/// Record settlement state notifier
final recordSettlementProvider = StateNotifierProvider.autoDispose<
    RecordSettlementNotifier, AsyncValue<Settlement?>>(
  (ref) => RecordSettlementNotifier(ref),
);

class RecordSettlementNotifier extends StateNotifier<AsyncValue<Settlement?>> {
  final Ref _ref;

  RecordSettlementNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> recordSettlement(Settlement settlement) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(settlementRepositoryProvider);
      final result = await repo.create(settlement);
      if (result.error != null) {
        state = AsyncValue.error(result.error!, StackTrace.current);
      } else {
        state = AsyncValue.data(result.data);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> completeSettlement(String settlementId) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(settlementRepositoryProvider);
      final result = await repo.complete(settlementId);
      if (result.error != null) {
        state = AsyncValue.error(result.error!, StackTrace.current);
      } else {
        state = AsyncValue.data(result.data);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> cancelSettlement(String settlementId) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(settlementRepositoryProvider);
      await repo.cancel(settlementId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

