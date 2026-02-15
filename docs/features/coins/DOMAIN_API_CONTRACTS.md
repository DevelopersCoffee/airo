# Domain Layer API Contracts: Coins Feature

## Document Information

| Field | Value |
|-------|-------|
| **Feature** | Coins - Financial Management |
| **Author** | Airo Engineering Team |
| **Status** | Draft |
| **Created** | 2026-02-15 |
| **Last Updated** | 2026-02-15 |

---

## 1. Overview

This document defines the domain layer API contracts for the Coins feature, including repository interfaces, use cases, data models, and service contracts. All contracts follow patterns established in `packages/core_domain`.

---

## 2. Repository Interfaces

### 2.1 TransactionRepository (Extended)

```dart
/// Extended transaction repository for Coins
/// Base interface: packages/core_domain/lib/src/repositories/repository.dart
abstract class TransactionRepository extends PaginatedRepository<Transaction> {
  /// Find transactions by account
  Future<Result<List<Transaction>>> findByAccount(String accountId);
  
  /// Find transactions by category
  Future<Result<List<Transaction>>> findByCategory(
    String category, {
    DateTime? startDate,
    DateTime? endDate,
  });
  
  /// Find transactions by date range
  Future<Result<List<Transaction>>> findByDateRange(
    DateTime start,
    DateTime end, {
    String? accountId,
    String? category,
  });
  
  /// Get spending summary by category
  Future<Result<Map<String, int>>> getSpendingByCategory(
    DateTime start,
    DateTime end,
  );
  
  /// Get daily totals
  Future<Result<List<DailyTotal>>> getDailyTotals(
    DateTime start,
    DateTime end,
  );
  
  /// Search transactions by description/vendor
  Future<Result<List<Transaction>>> search(String query);
  
  /// Find transactions with receipts
  Future<Result<List<Transaction>>> findWithReceipts();
  
  /// Soft delete (for undo support)
  Future<Result<void>> softDelete(String id);
  
  /// Restore soft-deleted transaction
  Future<Result<Transaction>> restore(String id);
  
  /// Get last N transactions
  Future<Result<List<Transaction>>> findRecent(int limit);
}
```

### 2.2 BudgetRepository (Extended)

```dart
/// Extended budget repository for Coins
abstract class BudgetRepository extends Repository<Budget> {
  /// Find budget for category and period
  Future<Result<Budget?>> findByCategoryAndPeriod(
    String category,
    int periodMonth, // YYYYMM format
  );
  
  /// Find all budgets for a period
  Future<Result<List<Budget>>> findByPeriod(int periodMonth);
  
  /// Get budget utilization
  Future<Result<BudgetUtilization>> getUtilization(String budgetId);
  
  /// Get all budgets with utilization for period
  Future<Result<List<BudgetWithUtilization>>> getAllWithUtilization(int periodMonth);
  
  /// Calculate safe-to-spend amount
  Future<Result<SafeToSpend>> calculateSafeToSpend(int periodMonth);
  
  /// Roll over unused budget to next period
  Future<Result<void>> rolloverBudget(String budgetId, int toPeriod);
  
  /// Bulk create budgets (from template)
  Future<Result<List<Budget>>> createBulk(List<Budget> budgets);
}
```

### 2.3 GroupRepository (New)

```dart
/// Repository for expense sharing groups
abstract class GroupRepository extends Repository<Group> {
  /// Find groups for user
  Future<Result<List<Group>>> findByUser(String userId);
  
  /// Find group by invite code
  Future<Result<Group?>> findByInviteCode(String code);
  
  /// Add member to group
  Future<Result<GroupMember>> addMember(String groupId, GroupMember member);
  
  /// Remove member from group
  Future<Result<void>> removeMember(String groupId, String memberId);
  
  /// Get group members
  Future<Result<List<GroupMember>>> getMembers(String groupId);
  
  /// Generate invite code
  Future<Result<String>> generateInviteCode(String groupId);
  
  /// Archive group
  Future<Result<void>> archive(String groupId);
}
```

### 2.4 ExpenseRepository (New)

```dart
/// Repository for shared expenses
abstract class ExpenseRepository extends PaginatedRepository<SharedExpense> {
  /// Find expenses by group
  Future<Result<List<SharedExpense>>> findByGroup(String groupId);
  
  /// Find expenses paid by user
  Future<Result<List<SharedExpense>>> findPaidBy(String userId);
  
  /// Find expenses involving user
  Future<Result<List<SharedExpense>>> findInvolving(String userId);
  
  /// Get expenses with splits
  Future<Result<List<ExpenseWithSplits>>> findByGroupWithSplits(String groupId);
  
  /// Get user's share in expense
  Future<Result<int>> getUserShare(String expenseId, String userId);
}
```

### 2.5 SplitRepository (New)

```dart
/// Repository for expense splits
abstract class SplitRepository extends Repository<Split> {
  /// Find splits for expense
  Future<Result<List<Split>>> findByExpense(String expenseId);
  
  /// Find splits for user
  Future<Result<List<Split>>> findByUser(String userId);
  
  /// Find unsettled splits for user
  Future<Result<List<Split>>> findUnsettled(String userId);
  
  /// Mark split as settled
  Future<Result<Split>> markSettled(String splitId, String settlementId);
  
  /// Bulk create splits
  Future<Result<List<Split>>> createBulk(List<Split> splits);
}
```

### 2.6 SettlementRepository (New)

```dart
/// Repository for settlements between users
abstract class SettlementRepository extends Repository<Settlement> {
  /// Find settlements between two users
  Future<Result<List<Settlement>>> findBetweenUsers(
    String userId1,
    String userId2,
  );
  
  /// Find settlements by group
  Future<Result<List<Settlement>>> findByGroup(String groupId);
  
  /// Find pending settlements for user
  Future<Result<List<Settlement>>> findPending(String userId);
  
  /// Confirm settlement
  Future<Result<Settlement>> confirm(String settlementId);
  
  /// Reject settlement
  Future<Result<Settlement>> reject(String settlementId, String reason);
}
```

### 2.7 SubscriptionRepository (New)

```dart
/// Repository for recurring subscriptions
abstract class SubscriptionRepository extends Repository<Subscription> {
  /// Find active subscriptions
  Future<Result<List<Subscription>>> findActive();

  /// Find subscriptions due in date range
  Future<Result<List<Subscription>>> findDueInRange(
    DateTime start,
    DateTime end,
  );

  /// Calculate monthly subscription cost
  Future<Result<int>> getMonthlyTotal();

  /// Pause subscription
  Future<Result<Subscription>> pause(String subscriptionId);

  /// Resume subscription
  Future<Result<Subscription>> resume(String subscriptionId);

  /// Mark as cancelled
  Future<Result<void>> cancel(String subscriptionId);
}
```

### 2.8 InvestmentRepository (New)

```dart
/// Repository for investment tracking
abstract class InvestmentRepository extends Repository<Investment> {
  /// Find investments by type
  Future<Result<List<Investment>>> findByType(InvestmentType type);

  /// Get total invested amount
  Future<Result<int>> getTotalInvested();

  /// Get investment summary by type
  Future<Result<Map<InvestmentType, int>>> getSummaryByType();

  /// Log investment transaction (SIP, lumpsum, withdrawal)
  Future<Result<InvestmentTransaction>> logTransaction(
    String investmentId,
    InvestmentTransaction transaction,
  );

  /// Get transaction history for investment
  Future<Result<List<InvestmentTransaction>>> getTransactions(String investmentId);
}
```

---

## 3. Use Case Interfaces

### 3.1 Expense Use Cases

```dart
/// Add expense use case
/// Pattern: packages/core_domain/lib/src/use_cases/use_case.dart
class AddExpenseUseCase implements UseCase<AddExpenseInput, Transaction> {
  final TransactionRepository _transactionRepo;
  final BudgetRepository _budgetRepo;

  AddExpenseUseCase(this._transactionRepo, this._budgetRepo);

  @override
  Future<Result<Transaction>> call(AddExpenseInput input) async {
    // 1. Validate input
    final validation = input.validate();
    if (validation.isErr) return Result.err(validation.error);

    // 2. Create transaction
    final transaction = Transaction(
      id: _generateId(),
      accountId: input.accountId,
      amountCents: -input.amountPaise, // Negative for expense
      description: input.description,
      category: input.category,
      timestamp: input.date,
      receiptUrl: input.receiptUrl,
      tags: input.tags,
    );

    // 3. Save transaction
    final result = await _transactionRepo.save(transaction);

    // 4. Update budget utilization
    if (result.isOk) {
      await _budgetRepo.updateUtilization(
        input.category,
        input.amountPaise,
        input.date,
      );
    }

    return result;
  }
}

class AddExpenseInput {
  final String accountId;
  final int amountPaise;
  final String description;
  final String category;
  final DateTime date;
  final String? receiptUrl;
  final List<String> tags;

  const AddExpenseInput({
    required this.accountId,
    required this.amountPaise,
    required this.description,
    required this.category,
    required this.date,
    this.receiptUrl,
    this.tags = const [],
  });

  Result<void> validate() {
    if (amountPaise <= 0) return Result.err(ValidationError('Amount must be positive'));
    if (description.isEmpty) return Result.err(ValidationError('Description required'));
    if (category.isEmpty) return Result.err(ValidationError('Category required'));
    return Result.ok(null);
  }
}
```

### 3.2 Split Use Cases

```dart
/// Create split expense use case
class CreateSplitUseCase implements UseCase<CreateSplitInput, ExpenseWithSplits> {
  final ExpenseRepository _expenseRepo;
  final SplitRepository _splitRepo;
  final GroupRepository _groupRepo;

  @override
  Future<Result<ExpenseWithSplits>> call(CreateSplitInput input) async {
    // 1. Validate group exists and user is member
    if (input.groupId != null) {
      final group = await _groupRepo.findById(input.groupId!);
      if (group.isErr) return Result.err(group.error);
    }

    // 2. Calculate splits based on type
    final splits = _calculateSplits(input);

    // 3. Create expense
    final expense = SharedExpense(
      id: _generateId(),
      groupId: input.groupId,
      paidBy: input.paidBy,
      amountPaise: input.amountPaise,
      description: input.description,
      splitType: input.splitType,
      date: input.date,
    );

    final expenseResult = await _expenseRepo.save(expense);
    if (expenseResult.isErr) return Result.err(expenseResult.error);

    // 4. Create splits
    final splitsResult = await _splitRepo.createBulk(splits);
    if (splitsResult.isErr) return Result.err(splitsResult.error);

    return Result.ok(ExpenseWithSplits(
      expense: expenseResult.value,
      splits: splitsResult.value,
    ));
  }

  List<Split> _calculateSplits(CreateSplitInput input) {
    switch (input.splitType) {
      case SplitType.equal:
        return _equalSplit(input);
      case SplitType.percentage:
        return _percentageSplit(input);
      case SplitType.exact:
        return _exactSplit(input);
      case SplitType.shares:
        return _sharesSplit(input);
    }
  }
}

class CreateSplitInput {
  final String? groupId;
  final String paidBy;
  final int amountPaise;
  final String description;
  final SplitType splitType;
  final List<SplitParticipant> participants;
  final DateTime date;

  const CreateSplitInput({
    this.groupId,
    required this.paidBy,
    required this.amountPaise,
    required this.description,
    required this.splitType,
    required this.participants,
    required this.date,
  });
}
```

### 3.3 Balance Use Cases

```dart
/// Calculate balances between users
class CalculateBalancesUseCase implements UseCase<String, UserBalances> {
  final SplitRepository _splitRepo;
  final SettlementRepository _settlementRepo;

  @override
  Future<Result<UserBalances>> call(String userId) async {
    // 1. Get all splits involving user
    final splits = await _splitRepo.findByUser(userId);
    if (splits.isErr) return Result.err(splits.error);

    // 2. Get all settlements involving user
    final settlements = await _settlementRepo.findPending(userId);
    if (settlements.isErr) return Result.err(settlements.error);

    // 3. Calculate net balance with each person
    final balances = _calculateNetBalances(
      userId,
      splits.value,
      settlements.value,
    );

    return Result.ok(balances);
  }
}

class UserBalances {
  final String userId;
  final int totalOwed;      // Amount user owes others
  final int totalOwedToUser; // Amount others owe user
  final List<PersonBalance> balances;

  int get netBalance => totalOwedToUser - totalOwed;
}

class PersonBalance {
  final String personId;
  final String personName;
  final int balance; // Positive = they owe user, Negative = user owes them
}
```

### 3.4 Budget Use Cases

```dart
/// Calculate safe-to-spend amount
class CalculateSafeToSpendUseCase implements NoInputUseCase<SafeToSpend> {
  final BudgetRepository _budgetRepo;
  final TransactionRepository _transactionRepo;

  @override
  Future<Result<SafeToSpend>> call() async {
    final now = DateTime.now();
    final periodMonth = now.year * 100 + now.month;

    // 1. Get total budget for period
    final budgets = await _budgetRepo.findByPeriod(periodMonth);
    if (budgets.isErr) return Result.err(budgets.error);

    final totalBudget = budgets.value.fold<int>(0, (sum, b) => sum + b.limitCents);

    // 2. Get spending so far
    final startOfMonth = DateTime(now.year, now.month, 1);
    final spending = await _transactionRepo.findByDateRange(startOfMonth, now);
    if (spending.isErr) return Result.err(spending.error);

    final totalSpent = spending.value
        .where((t) => t.amountCents < 0)
        .fold<int>(0, (sum, t) => sum + t.amountCents.abs());

    // 3. Calculate remaining days
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = daysInMonth - now.day + 1;

    // 4. Calculate safe-to-spend
    final remaining = totalBudget - totalSpent;
    final dailyLimit = remaining ~/ remainingDays;

    return Result.ok(SafeToSpend(
      totalBudget: totalBudget,
      totalSpent: totalSpent,
      remaining: remaining,
      dailyLimit: dailyLimit,
      remainingDays: remainingDays,
    ));
  }
}

class SafeToSpend {
  final int totalBudget;
  final int totalSpent;
  final int remaining;
  final int dailyLimit;
  final int remainingDays;

  double get utilizationPercent => (totalSpent / totalBudget) * 100;
  bool get isOverBudget => remaining < 0;
}
```

### 3.5 Receipt Use Cases

```dart
/// Process receipt and create transaction
class ProcessReceiptUseCase implements UseCase<ProcessReceiptInput, Transaction> {
  final ReceiptImagePreprocessor _preprocessor;
  final ReceiptTextRecognizer _recognizer;
  final GemmaReceiptParser _parser;
  final ReceiptCategoryClassifier _classifier;
  final TransactionRepository _transactionRepo;
  final ReceiptStorageService _storageService;

  @override
  Future<Result<Transaction>> call(ProcessReceiptInput input) async {
    // 1. Preprocess image
    final preprocessed = await _preprocessor.preprocess(input.imageFile);

    // 2. OCR extraction
    final ocrResult = await _recognizer.recognize(preprocessed);

    // 3. Parse with Gemma
    final parsed = await _parser.parse(ocrResult);
    if (parsed.isErr) return Result.err(parsed.error);

    // 4. Classify category
    final category = _classifier.classify(parsed.value);

    // 5. Create transaction
    final transaction = Transaction(
      id: _generateId(),
      accountId: input.accountId,
      amountCents: -parsed.value.totalPaise,
      description: parsed.value.vendor ?? 'Receipt expense',
      category: category.name,
      timestamp: parsed.value.date ?? DateTime.now(),
      tags: [],
    );

    // 6. Save transaction
    final result = await _transactionRepo.save(transaction);
    if (result.isErr) return result;

    // 7. Store receipt image
    final receiptPath = await _storageService.saveReceiptImage(
      input.imageFile,
      transaction.id,
    );

    // 8. Update transaction with receipt URL
    return _transactionRepo.save(
      transaction.copyWith(receiptUrl: receiptPath),
    );
  }
}

class ProcessReceiptInput {
  final File imageFile;
  final String accountId;

  const ProcessReceiptInput({
    required this.imageFile,
    required this.accountId,
  });
}
```

### 3.6 Daily Summary Use Case

```dart
/// Generate daily financial summary
class GenerateDailySummaryUseCase implements UseCase<DateTime, DailySummary> {
  final TransactionRepository _transactionRepo;
  final BudgetRepository _budgetRepo;

  @override
  Future<Result<DailySummary>> call(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // 1. Get day's transactions
    final transactions = await _transactionRepo.findByDateRange(
      startOfDay,
      endOfDay,
    );
    if (transactions.isErr) return Result.err(transactions.error);

    // 2. Calculate totals
    final expenses = transactions.value.where((t) => t.amountCents < 0);
    final income = transactions.value.where((t) => t.amountCents > 0);

    final totalExpenses = expenses.fold<int>(0, (s, t) => s + t.amountCents.abs());
    final totalIncome = income.fold<int>(0, (s, t) => s + t.amountCents);

    // 3. Get top categories
    final byCategory = <String, int>{};
    for (final t in expenses) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amountCents.abs();
    }

    final topCategories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 4. Get budget status
    final safeToSpend = await _calculateSafeToSpend(date);

    return Result.ok(DailySummary(
      date: date,
      totalExpenses: totalExpenses,
      totalIncome: totalIncome,
      transactionCount: transactions.value.length,
      topCategories: topCategories.take(3).toList(),
      safeToSpendRemaining: safeToSpend,
      insights: _generateInsights(transactions.value, byCategory),
    ));
  }
}

class DailySummary {
  final DateTime date;
  final int totalExpenses;
  final int totalIncome;
  final int transactionCount;
  final List<MapEntry<String, int>> topCategories;
  final int safeToSpendRemaining;
  final List<String> insights;
}
```

---

## 4. Data Models

### 4.1 Core Entities

```dart
/// Transaction entity
class Transaction extends Entity {
  final String accountId;
  final DateTime timestamp;
  final int amountCents;       // Negative for expenses
  final String description;
  final String category;
  final List<String> tags;
  final String? receiptUrl;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;   // For soft delete

  const Transaction({
    required super.id,
    required this.accountId,
    required this.timestamp,
    required this.amountCents,
    required this.description,
    required this.category,
    this.tags = const [],
    this.receiptUrl,
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  bool get isExpense => amountCents < 0;
  bool get isIncome => amountCents > 0;
  int get absoluteAmount => amountCents.abs();
}

/// Budget entity
class Budget extends Entity {
  final String category;
  final int limitCents;
  final int usedCents;
  final int carryoverCents;
  final int periodMonth;        // YYYYMM format
  final Recurrence recurrence;
  final CarryoverBehavior carryoverBehavior;

  const Budget({
    required super.id,
    required this.category,
    required this.limitCents,
    this.usedCents = 0,
    this.carryoverCents = 0,
    required this.periodMonth,
    this.recurrence = Recurrence.monthly,
    this.carryoverBehavior = CarryoverBehavior.none,
  });

  int get remainingCents => limitCents + carryoverCents - usedCents;
  double get utilizationPercent => (usedCents / limitCents) * 100;
  bool get isOverBudget => usedCents > limitCents + carryoverCents;
}

enum Recurrence { daily, weekly, monthly, yearly }
enum CarryoverBehavior { none, rollover, reset }
```

### 4.2 Split-Related Entities

```dart
/// Group for expense sharing
class Group extends Entity {
  final String name;
  final String? description;
  final String createdBy;
  final GroupType type;
  final String? inviteCode;
  final DateTime createdAt;
  final DateTime? archivedAt;

  const Group({
    required super.id,
    required this.name,
    this.description,
    required this.createdBy,
    this.type = GroupType.general,
    this.inviteCode,
    required this.createdAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;
}

enum GroupType { general, trip, home, couple, friends, work }

/// Group member
class GroupMember extends Entity {
  final String groupId;
  final String userId;
  final String name;
  final String? email;
  final String? phone;
  final GroupRole role;
  final DateTime joinedAt;

  const GroupMember({
    required super.id,
    required this.groupId,
    required this.userId,
    required this.name,
    this.email,
    this.phone,
    this.role = GroupRole.member,
    required this.joinedAt,
  });
}

enum GroupRole { admin, member }

/// Shared expense
class SharedExpense extends Entity {
  final String? groupId;
  final String paidBy;
  final int amountPaise;
  final String description;
  final SplitType splitType;
  final DateTime date;
  final String? receiptUrl;
  final DateTime createdAt;

  const SharedExpense({
    required super.id,
    this.groupId,
    required this.paidBy,
    required this.amountPaise,
    required this.description,
    required this.splitType,
    required this.date,
    this.receiptUrl,
    required this.createdAt,
  });
}

enum SplitType { equal, percentage, exact, shares }

/// Individual split
class Split extends Entity {
  final String expenseId;
  final String userId;
  final int amountPaise;
  final double? percentage;
  final int? shares;
  final bool isSettled;
  final String? settlementId;

  const Split({
    required super.id,
    required this.expenseId,
    required this.userId,
    required this.amountPaise,
    this.percentage,
    this.shares,
    this.isSettled = false,
    this.settlementId,
  });
}

/// Settlement between users
class Settlement extends Entity {
  final String? groupId;
  final String fromUserId;
  final String toUserId;
  final int amountPaise;
  final SettlementMethod method;
  final SettlementStatus status;
  final String? note;
  final DateTime createdAt;
  final DateTime? settledAt;

  const Settlement({
    required super.id,
    this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amountPaise,
    this.method = SettlementMethod.cash,
    this.status = SettlementStatus.pending,
    this.note,
    required this.createdAt,
    this.settledAt,
  });
}

enum SettlementMethod { cash, upi, bankTransfer, other }
enum SettlementStatus { pending, confirmed, rejected }
```

### 4.3 Subscription & Investment Entities

```dart
/// Recurring subscription
class Subscription extends Entity {
  final String name;
  final String? vendor;
  final int amountPaise;
  final Currency currency;
  final SubscriptionFrequency frequency;
  final DateTime startDate;
  final DateTime? nextBillingDate;
  final String category;
  final SubscriptionStatus status;

  const Subscription({
    required super.id,
    required this.name,
    this.vendor,
    required this.amountPaise,
    this.currency = Currency.inr,
    required this.frequency,
    required this.startDate,
    this.nextBillingDate,
    required this.category,
    this.status = SubscriptionStatus.active,
  });

  /// Calculate monthly equivalent
  int get monthlyEquivalent => switch (frequency) {
    SubscriptionFrequency.daily => amountPaise * 30,
    SubscriptionFrequency.weekly => amountPaise * 4,
    SubscriptionFrequency.monthly => amountPaise,
    SubscriptionFrequency.quarterly => amountPaise ~/ 3,
    SubscriptionFrequency.yearly => amountPaise ~/ 12,
  };
}

enum SubscriptionFrequency { daily, weekly, monthly, quarterly, yearly }
enum SubscriptionStatus { active, paused, cancelled }

/// Investment entry
class Investment extends Entity {
  final String name;
  final InvestmentType type;
  final String? platform;
  final int totalInvestedPaise;
  final int currentValuePaise;
  final DateTime startDate;
  final SIPDetails? sipDetails;

  const Investment({
    required super.id,
    required this.name,
    required this.type,
    this.platform,
    required this.totalInvestedPaise,
    required this.currentValuePaise,
    required this.startDate,
    this.sipDetails,
  });

  int get returns => currentValuePaise - totalInvestedPaise;
  double get returnsPercent => (returns / totalInvestedPaise) * 100;
}

enum InvestmentType { mutualFund, stocks, fixedDeposit, ppf, nps, gold, crypto, other }

class SIPDetails {
  final int amountPaise;
  final int dayOfMonth;
  final DateTime nextDeduction;
  final bool isActive;

  const SIPDetails({
    required this.amountPaise,
    required this.dayOfMonth,
    required this.nextDeduction,
    this.isActive = true,
  });
}
```

---

## 5. Service Contracts

### 5.1 SplitCalculatorService

```dart
/// Service for calculating splits
abstract class SplitCalculatorService {
  /// Calculate equal split
  List<SplitAmount> calculateEqual({
    required int totalPaise,
    required List<String> participantIds,
  });

  /// Calculate percentage split
  List<SplitAmount> calculatePercentage({
    required int totalPaise,
    required Map<String, double> percentages,
  });

  /// Calculate exact amount split
  List<SplitAmount> calculateExact({
    required int totalPaise,
    required Map<String, int> exactAmounts,
  });

  /// Calculate shares-based split
  List<SplitAmount> calculateShares({
    required int totalPaise,
    required Map<String, int> shares,
  });

  /// Validate split totals match expense
  Result<void> validateSplit(int totalPaise, List<SplitAmount> splits);
}

class SplitAmount {
  final String participantId;
  final int amountPaise;
  final double? percentage;
  final int? shares;

  const SplitAmount({
    required this.participantId,
    required this.amountPaise,
    this.percentage,
    this.shares,
  });
}
```

### 5.2 BalanceEngineService

```dart
/// Service for calculating and simplifying balances
abstract class BalanceEngineService {
  /// Calculate balances between all members in a group
  Future<List<Balance>> calculateGroupBalances(String groupId);

  /// Calculate balance between two users
  Future<int> calculateBilateralBalance(String userId1, String userId2);

  /// Simplify debts (minimize transactions needed to settle)
  List<SimplifiedDebt> simplifyDebts(List<Balance> balances);

  /// Get suggested settlements
  List<SuggestedSettlement> getSuggestedSettlements(String userId);
}

class Balance {
  final String fromUserId;
  final String toUserId;
  final int amountPaise;
}

class SimplifiedDebt {
  final String payerId;
  final String payeeId;
  final int amountPaise;
}

class SuggestedSettlement {
  final String withUserId;
  final String withUserName;
  final int amountPaise;
  final bool userOwes; // true if current user owes, false if user is owed
}
```

### 5.3 BudgetTrackerService

```dart
/// Service for budget tracking and alerts
abstract class BudgetTrackerService {
  /// Check if transaction would exceed budget
  Future<BudgetCheckResult> checkBudget({
    required String category,
    required int amountPaise,
  });

  /// Get budget alerts
  Future<List<BudgetAlert>> getAlerts(int periodMonth);

  /// Get spending pace (on track, over, under)
  Future<SpendingPace> getSpendingPace(String category);

  /// Project month-end spending
  Future<int> projectMonthEndSpending(String category);
}

class BudgetCheckResult {
  final bool withinBudget;
  final int remainingAfter;
  final double utilizationAfter;
  final String? warning;
}

class BudgetAlert {
  final String category;
  final AlertType type;
  final String message;
  final int threshold;
  final int current;
}

enum AlertType { approaching, exceeded, onTrack }

class SpendingPace {
  final String category;
  final PaceStatus status;
  final int expectedByNow;
  final int actualSpent;
  final int projectedTotal;
}

enum PaceStatus { underPace, onPace, overPace }
```

### 5.4 CategoryClassifierService

```dart
/// Service for AI-powered category classification
abstract class CategoryClassifierService {
  /// Classify transaction from description
  Future<CategoryPrediction> classifyFromText(String description);

  /// Classify from receipt
  Future<CategoryPrediction> classifyFromReceipt(ParsedReceipt receipt);

  /// Get user's common categories
  Future<List<String>> getUserCategories();

  /// Learn from user corrections
  Future<void> learnCorrection(String description, String correctCategory);
}

class CategoryPrediction {
  final String category;
  final double confidence;
  final List<CategoryAlternative> alternatives;
}

class CategoryAlternative {
  final String category;
  final double confidence;
}
```

---

## 6. Database Schema Extensions

### 6.1 New Tables (Migration v3 → v4)

```dart
/// Groups table
class GroupEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get createdBy => text()();
  TextColumn get groupType => text().withDefault(const Constant('general'))();
  TextColumn get inviteCode => text().nullable().unique()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
}

/// Group members table
class GroupMemberEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get groupId => text().references(GroupEntries, #uuid)();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get role => text().withDefault(const Constant('member'))();
  DateTimeColumn get joinedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Shared expenses table
class SharedExpenseEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get groupId => text().nullable().references(GroupEntries, #uuid)();
  TextColumn get paidBy => text()();
  IntColumn get amountPaise => integer()();
  TextColumn get description => text()();
  TextColumn get splitType => text()();
  TextColumn get receiptUrl => text().nullable()();
  DateTimeColumn get expenseDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
}

/// Splits table
class SplitEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get expenseId => text().references(SharedExpenseEntries, #uuid)();
  TextColumn get userId => text()();
  IntColumn get amountPaise => integer()();
  RealColumn get percentage => real().nullable()();
  IntColumn get shares => integer().nullable()();
  BoolColumn get isSettled => boolean().withDefault(const Constant(false))();
  TextColumn get settlementId => text().nullable()();
}

/// Settlements table
class SettlementEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get groupId => text().nullable().references(GroupEntries, #uuid)();
  TextColumn get fromUserId => text()();
  TextColumn get toUserId => text()();
  IntColumn get amountPaise => integer()();
  TextColumn get method => text().withDefault(const Constant('cash'))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get settledAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
}

/// Subscriptions table
class SubscriptionEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get vendor => text().nullable()();
  IntColumn get amountPaise => integer()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  TextColumn get frequency => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get nextBillingDate => dateTime().nullable()();
  TextColumn get category => text()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
}

/// Investments table
class InvestmentEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get investmentType => text()();
  TextColumn get platform => text().nullable()();
  IntColumn get totalInvestedPaise => integer()();
  IntColumn get currentValuePaise => integer()();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get sipAmountPaise => integer().nullable()();
  IntColumn get sipDayOfMonth => integer().nullable()();
  DateTimeColumn get sipNextDeduction => dateTime().nullable()();
  BoolColumn get sipActive => boolean().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
}

/// Receipt text index for search
class ReceiptTextEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get transactionId => text().references(TransactionEntries, #uuid)();
  TextColumn get fullText => text()();
  TextColumn get keywords => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

### 6.2 Migration Script

```dart
// Migration from v3 to v4
if (from < 4) {
  // Create new tables
  await m.createTable(groupEntries);
  await m.createTable(groupMemberEntries);
  await m.createTable(sharedExpenseEntries);
  await m.createTable(splitEntries);
  await m.createTable(settlementEntries);
  await m.createTable(subscriptionEntries);
  await m.createTable(investmentEntries);
  await m.createTable(receiptTextEntries);

  // Create indexes
  await m.createIndex(Index(
    'idx_groups_created_by',
    'CREATE INDEX idx_groups_created_by ON group_entries(created_by)',
  ));
  await m.createIndex(Index(
    'idx_group_members_group',
    'CREATE INDEX idx_group_members_group ON group_member_entries(group_id)',
  ));
  await m.createIndex(Index(
    'idx_expenses_group',
    'CREATE INDEX idx_expenses_group ON shared_expense_entries(group_id)',
  ));
  await m.createIndex(Index(
    'idx_splits_expense',
    'CREATE INDEX idx_splits_expense ON split_entries(expense_id)',
  ));
  await m.createIndex(Index(
    'idx_settlements_users',
    'CREATE INDEX idx_settlements_users ON settlement_entries(from_user_id, to_user_id)',
  ));
  await m.createIndex(Index(
    'idx_subscriptions_status',
    'CREATE INDEX idx_subscriptions_status ON subscription_entries(status, next_billing_date)',
  ));

  // Add soft delete column to transactions
  await m.addColumn(
    transactionEntries,
    GeneratedColumn('deleted_at', DriftSqlType.dateTime, true),
  );
}
```

---

## 7. Error Types

```dart
/// Domain-specific errors for Coins
sealed class CoinsError {
  final String message;
  final String code;

  const CoinsError(this.message, this.code);
}

// Transaction errors
class InsufficientBalanceError extends CoinsError {
  const InsufficientBalanceError() : super('Insufficient balance', 'E001');
}

class DuplicateTransactionError extends CoinsError {
  const DuplicateTransactionError() : super('Duplicate transaction detected', 'E002');
}

// Budget errors
class BudgetExceededError extends CoinsError {
  final int overage;
  const BudgetExceededError(this.overage) : super('Budget exceeded', 'E010');
}

class NoBudgetSetError extends CoinsError {
  const NoBudgetSetError() : super('No budget set for category', 'E011');
}

// Split errors
class InvalidSplitError extends CoinsError {
  const InvalidSplitError(String details) : super(details, 'E020');
}

class UserNotInGroupError extends CoinsError {
  const UserNotInGroupError() : super('User not in group', 'E021');
}

class SettlementMismatchError extends CoinsError {
  const SettlementMismatchError() : super('Settlement amount mismatch', 'E022');
}

// Receipt errors
class ReceiptProcessingError extends CoinsError {
  const ReceiptProcessingError(String details) : super(details, 'E030');
}

class ImageQualityError extends CoinsError {
  const ImageQualityError() : super('Image quality too low', 'E031');
}

// Validation errors
class ValidationError extends CoinsError {
  final String field;
  const ValidationError(this.field, String message) : super(message, 'E100');
}
```

---

## 8. Integration Points

### 8.1 core_auth Integration

```dart
/// Get current user for transactions
final currentUser = ref.watch(currentUserProvider);

/// Use user ID for ownership
final expense = SharedExpense(
  paidBy: currentUser.id,
  ...
);
```

### 8.2 core_data Integration

```dart
/// Use sync service for offline-first
final syncService = ref.watch(syncServiceProvider);
await syncService.enqueue(
  operation: SyncOperation.create,
  entityType: 'transaction',
  payload: transaction.toJson(),
);
```

### 8.3 core_ai Integration

```dart
/// Use LLM router for AI features
final llmRouter = ref.watch(llmRouterProvider);
final client = await llmRouter.route(
  prompt: classificationPrompt,
  preferOnDevice: true,
);
```

---

**Document History**

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-02-15 | 1.0 | Airo Team | Initial draft |
```
```
```

