# Coins Feature - Project Structure

> **Document Type**: Technical Specification  
> **Version**: 1.0  
> **Last Updated**: 2026-02-15  
> **Status**: Draft

---

## Table of Contents

1. [Overview](#overview)
2. [Folder Structure](#folder-structure)
3. [Domain Layer](#domain-layer)
4. [Application Layer](#application-layer)
5. [Data Layer](#data-layer)
6. [Presentation Layer](#presentation-layer)
7. [Core Services Integration](#core-services-integration)
8. [Test Structure](#test-structure)
9. [File Descriptions](#file-descriptions)
10. [Dependencies](#dependencies)

---

## Overview

The Coins feature follows Domain-Driven Design (DDD) architecture with clean separation of concerns. This document defines the complete file structure for implementation, following patterns established in existing features like `money`, `bill_split`, and `quotes`.

### Design Principles

1. **Offline-first**: All data persisted locally with encrypted storage
2. **Privacy-first**: AI processing on-device using Gemini Nano / Gemma
3. **Modular**: Each subdomain (expense, budget, split, mind) is self-contained
4. **Testable**: Clean interfaces enable comprehensive unit testing
5. **Scalable**: Structure supports Phase 1-5 incremental delivery

---

## Folder Structure

```
app/lib/features/coins/
├── coins.dart                          # Public barrel export
├── README.md                           # Feature documentation
│
├── domain/                             # Domain layer - Business logic
│   ├── entities/                       # Core business entities
│   │   ├── transaction.dart            # Transaction entity
│   │   ├── budget.dart                 # Budget entity
│   │   ├── account.dart                # Account entity
│   │   ├── category.dart               # Category entity
│   │   ├── group.dart                  # Group entity (Phase 2)
│   │   ├── group_member.dart           # Group member entity (Phase 2)
│   │   ├── shared_expense.dart         # Shared expense entity (Phase 2)
│   │   ├── split_entry.dart            # Split entry entity (Phase 2)
│   │   ├── settlement.dart             # Settlement entity (Phase 2)
│   │   ├── subscription.dart           # Subscription entity (Phase 3)
│   │   └── investment.dart             # Investment entity (Phase 4)
│   │
│   ├── models/                         # Value objects and DTOs
│   │   ├── safe_to_spend.dart          # Safe-to-spend calculation result
│   │   ├── budget_status.dart          # Budget status model
│   │   ├── balance_summary.dart        # Balance summary for groups
│   │   ├── debt_entry.dart             # Who owes whom entry
│   │   └── currency.dart               # Currency enum and utilities
│   │
│   ├── repositories/                   # Repository interfaces (abstract)
│   │   ├── transaction_repository.dart
│   │   ├── budget_repository.dart
│   │   ├── account_repository.dart
│   │   ├── group_repository.dart
│   │   └── settlement_repository.dart
│   │
│   ├── services/                       # Domain service interfaces
│   │   ├── budget_engine.dart          # Budget calculation service
│   │   ├── balance_engine.dart         # Group balance calculation
│   │   ├── split_calculator.dart       # Split type calculations
│   │   └── debt_simplifier.dart        # Debt simplification algorithm
│   │
│   └── errors/                         # Domain-specific errors
│       └── coins_errors.dart           # Error types and messages
│
├── application/                        # Application layer - Use cases & state
│   ├── providers/                      # Riverpod providers
│   │   ├── expense_providers.dart      # Expense-related providers
│   │   ├── budget_providers.dart       # Budget-related providers
│   │   ├── group_providers.dart        # Group-related providers
│   │   ├── split_providers.dart        # Split-related providers
│   │   ├── settlement_providers.dart   # Settlement providers
│   │   └── dashboard_providers.dart    # Dashboard aggregation providers
│   │
│   ├── use_cases/                      # Use case implementations
│   │   ├── add_expense_use_case.dart
│   │   ├── update_expense_use_case.dart
│   │   ├── delete_expense_use_case.dart
│   │   ├── set_budget_use_case.dart
│   │   ├── create_group_use_case.dart
│   │   ├── add_split_use_case.dart
│   │   ├── calculate_balances_use_case.dart
│   │   ├── record_settlement_use_case.dart
│   │   └── calculate_safe_to_spend_use_case.dart
│   │
│   └── services/                       # Application services
│       ├── coins_notification_service.dart
│       └── coins_sync_service.dart
│
├── data/                               # Data layer - External data sources
│   ├── repositories/                   # Repository implementations
│   │   ├── transaction_repository_impl.dart
│   │   ├── budget_repository_impl.dart
│   │   ├── account_repository_impl.dart
│   │   ├── group_repository_impl.dart
│   │   └── settlement_repository_impl.dart
│   │
│   ├── datasources/                    # Data sources
│   │   └── coins_local_datasource.dart # Drift database operations
│   │
│   └── mappers/                        # Entity <-> Database mappers
│       ├── transaction_mapper.dart
│       ├── budget_mapper.dart
│       ├── group_mapper.dart
│       └── settlement_mapper.dart
│
├── presentation/                       # Presentation layer - UI
│   ├── screens/                        # Full-screen widgets
│   │   ├── dashboard/
│   │   │   └── coins_dashboard_screen.dart
│   │   ├── expense/
│   │   │   ├── add_expense_screen.dart
│   │   │   ├── expense_detail_screen.dart
│   │   │   └── expense_list_screen.dart
│   │   ├── budget/
│   │   │   ├── budget_overview_screen.dart
│   │   │   └── budget_setup_screen.dart
│   │   ├── group/
│   │   │   ├── group_list_screen.dart
│   │   │   ├── group_detail_screen.dart
│   │   │   ├── create_group_screen.dart
│   │   │   └── member_management_screen.dart
│   │   ├── split/
│   │   │   ├── split_creation_screen.dart
│   │   │   ├── split_detail_screen.dart
│   │   │   └── split_history_screen.dart
│   │   └── settlement/
│   │       ├── settle_up_screen.dart
│   │       ├── settlement_confirmation_screen.dart
│   │       └── settlement_history_screen.dart
│   │
│   └── widgets/                        # Reusable components
│       ├── common/
│       │   ├── amount_display.dart
│       │   ├── category_icon.dart
│       │   ├── progress_bar.dart
│       │   └── date_selector.dart
│       ├── expense/
│       │   ├── expense_list_item.dart
│       │   ├── expense_form.dart
│       │   └── number_pad.dart
│       ├── budget/
│       │   ├── budget_card.dart
│       │   ├── safe_to_spend_widget.dart
│       │   └── budget_progress_ring.dart
│       ├── group/
│       │   ├── group_card.dart
│       │   ├── member_avatar.dart
│       │   └── balance_chip.dart
│       └── split/
│           ├── split_type_selector.dart
│           ├── member_split_row.dart
│           └── split_summary_card.dart
│
├── mind/                               # Mind AI subdomain (Phase 3)
│   ├── domain/
│   │   ├── models/
│   │   │   ├── mind_intent.dart
│   │   │   ├── extracted_entities.dart
│   │   │   ├── mind_action.dart
│   │   │   └── mind_message.dart
│   │   └── services/
│   │       ├── intent_classifier.dart
│   │       ├── entity_extractor.dart
│   │       └── action_executor.dart
│   ├── application/
│   │   ├── providers/
│   │   │   └── mind_providers.dart
│   │   └── use_cases/
│   │       ├── process_input_use_case.dart
│   │       └── execute_action_use_case.dart
│   └── presentation/
│       ├── screens/
│       │   └── mind_screen.dart
│       └── widgets/
│           ├── mind_chat_widget.dart
│           ├── confirmation_card_widget.dart
│           ├── mind_input_field.dart
│           └── suggested_prompts_widget.dart
│
└── receipt/                            # Receipt OCR subdomain (Phase 3)
    ├── domain/
    │   ├── models/
    │   │   ├── parsed_receipt.dart
    │   │   ├── line_item.dart
    │   │   ├── image_quality_result.dart
    │   │   └── receipt_processing_result.dart
    │   └── services/
    │       ├── receipt_image_preprocessor.dart
    │       ├── receipt_text_recognizer.dart
    │       ├── gemma_receipt_parser.dart
    │       ├── receipt_category_classifier.dart
    │       └── receipt_storage_service.dart
    ├── application/
    │   ├── providers/
    │   │   └── receipt_providers.dart
    │   └── use_cases/
    │       ├── process_receipt_use_case.dart
    │       └── search_receipts_use_case.dart
    └── presentation/
        ├── screens/
        │   └── receipt_scan_screen.dart
        └── widgets/
            ├── camera_preview_widget.dart
            ├── receipt_review_widget.dart
            └── processing_indicator_widget.dart
```

---

## Domain Layer

The domain layer contains pure business logic with no dependencies on external frameworks.

### Entities

Core business objects that have identity and lifecycle.

```dart
// transaction.dart
import 'package:equatable/equatable.dart';
import 'package:core_domain/core_domain.dart';

enum TransactionType { expense, income, transfer }

class Transaction extends Entity {
  final String description;
  final int amountCents; // Always stored in smallest currency unit
  final TransactionType type;
  final String categoryId;
  final String accountId;
  final DateTime transactionDate;
  final String? notes;
  final String? receiptId;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted; // Soft delete for undo support

  const Transaction({
    required String id,
    required this.description,
    required this.amountCents,
    required this.type,
    required this.categoryId,
    required this.accountId,
    required this.transactionDate,
    this.notes,
    this.receiptId,
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  }) : super(id: id);

  double get amount => amountCents / 100;

  Transaction copyWith({...});

  @override
  List<Object?> get props => [...];
}
```

```dart
// budget.dart
enum BudgetPeriod { daily, weekly, monthly, yearly }

class Budget extends Entity {
  final String categoryId;
  final int limitCents;
  final BudgetPeriod period;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final int alertThresholdPercent; // e.g., 80 for 80% warning

  const Budget({...});

  bool get isRecurring => endDate == null;
}
```

```dart
// group.dart
class Group extends Entity {
  final String name;
  final String? iconUrl;
  final Currency defaultCurrency;
  final List<GroupMember> members;
  final GroupSettings settings;
  final String creatorId;
  final String? inviteCode;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Group({...});

  bool get isMultiCurrency => members.any((m) => m.currency != defaultCurrency);
  int get memberCount => members.length;
}
```

### Repository Interfaces

Abstract contracts for data access.

```dart
// transaction_repository.dart
import 'package:core_domain/core_domain.dart';

abstract class TransactionRepository {
  Future<Result<Transaction>> findById(String id);
  Future<Result<List<Transaction>>> findByDateRange(DateTime start, DateTime end);
  Future<Result<List<Transaction>>> findByCategory(String categoryId);
  Future<Result<List<Transaction>>> findRecent({int limit = 10});
  Future<Result<Transaction>> create(Transaction transaction);
  Future<Result<Transaction>> update(Transaction transaction);
  Future<Result<void>> delete(String id); // Soft delete
  Future<Result<void>> hardDelete(String id);
  Stream<List<Transaction>> watchAll();
  Stream<List<Transaction>> watchByCategory(String categoryId);
}
```

### Domain Services

Pure business logic without side effects.

```dart
// budget_engine.dart
abstract class BudgetEngine {
  /// Calculate safe-to-spend amount for today
  Future<SafeToSpend> calculateSafeToSpend({
    required List<Budget> budgets,
    required List<Transaction> transactions,
    required DateTime currentDate,
  });

  /// Get budget status for a category
  BudgetStatus getBudgetStatus({
    required Budget budget,
    required List<Transaction> transactions,
    required DateTime currentDate,
  });

  /// Calculate days remaining in budget period
  int daysRemaining(Budget budget, DateTime currentDate);
}
```

---

## Application Layer

The application layer coordinates domain objects and implements use cases.

### Providers (Riverpod)

```dart
// expense_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/transaction.dart';
import '../domain/repositories/transaction_repository.dart';

/// Repository provider - injected from data layer
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  throw UnimplementedError('Must be overridden in main.dart');
});

/// Recent expenses stream
final recentExpensesProvider = StreamProvider<List<Transaction>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchAll();
});

/// Expenses by category
final expensesByCategoryProvider = StreamProvider.family<List<Transaction>, String>(
  (ref, categoryId) {
    final repo = ref.watch(transactionRepositoryProvider);
    return repo.watchByCategory(categoryId);
  },
);

/// Add expense state notifier
final addExpenseProvider = StateNotifierProvider.autoDispose<AddExpenseNotifier, AsyncValue<Transaction?>>(
  (ref) => AddExpenseNotifier(ref),
);

class AddExpenseNotifier extends StateNotifier<AsyncValue<Transaction?>> {
  final Ref _ref;

  AddExpenseNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> addExpense(Transaction expense) async {
    state = const AsyncValue.loading();
    final repo = _ref.read(transactionRepositoryProvider);
    final result = await repo.create(expense);
    state = result.fold(
      (error) => AsyncValue.error(error, StackTrace.current),
      (transaction) => AsyncValue.data(transaction),
    );
  }
}
```

### Use Cases

```dart
// add_expense_use_case.dart
import 'package:core_domain/core_domain.dart';
import '../domain/entities/transaction.dart';
import '../domain/repositories/transaction_repository.dart';

class AddExpenseUseCase implements UseCase<Transaction, AddExpenseParams> {
  final TransactionRepository _repository;

  AddExpenseUseCase(this._repository);

  @override
  Future<Result<Transaction>> call(AddExpenseParams params) async {
    // Validation
    if (params.amountCents <= 0) {
      return Result.failure(ValidationError('Amount must be positive'));
    }

    if (params.description.isEmpty) {
      return Result.failure(ValidationError('Description is required'));
    }

    // Create entity
    final transaction = Transaction(
      id: generateUuid(),
      description: params.description,
      amountCents: params.amountCents,
      type: TransactionType.expense,
      categoryId: params.categoryId,
      accountId: params.accountId,
      transactionDate: params.date,
      tags: params.tags,
      createdAt: DateTime.now(),
    );

    // Persist
    return _repository.create(transaction);
  }
}

class AddExpenseParams {
  final String description;
  final int amountCents;
  final String categoryId;
  final String accountId;
  final DateTime date;
  final List<String> tags;

  const AddExpenseParams({...});
}
```

---

## Data Layer

The data layer implements repository interfaces and handles persistence.

### Repository Implementations

```dart
// transaction_repository_impl.dart
import 'package:drift/drift.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/coins_local_datasource.dart';
import '../mappers/transaction_mapper.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final CoinsLocalDatasource _datasource;
  final TransactionMapper _mapper;

  TransactionRepositoryImpl(this._datasource, this._mapper);

  @override
  Future<Result<Transaction>> findById(String id) async {
    try {
      final entry = await _datasource.getTransactionById(id);
      if (entry == null) {
        return Result.failure(NotFoundError('Transaction not found'));
      }
      return Result.success(_mapper.toDomain(entry));
    } catch (e) {
      return Result.failure(DatabaseError(e.toString()));
    }
  }

  @override
  Stream<List<Transaction>> watchAll() {
    return _datasource.watchTransactions()
      .map((entries) => entries.map(_mapper.toDomain).toList());
  }

  @override
  Future<Result<Transaction>> create(Transaction transaction) async {
    try {
      final entry = _mapper.toEntry(transaction);
      await _datasource.insertTransaction(entry);
      return Result.success(transaction);
    } catch (e) {
      return Result.failure(DatabaseError(e.toString()));
    }
  }

  // ... other methods
}
```

### Datasources

```dart
// coins_local_datasource.dart
import 'package:drift/drift.dart';
import 'package:airo_app/core/database/app_database.dart';

/// Drift-based local data source for Coins feature
class CoinsLocalDatasource {
  final AppDatabase _db;

  CoinsLocalDatasource(this._db);

  // Transactions
  Future<TransactionEntry?> getTransactionById(String id) {
    return (_db.select(_db.transactionEntries)
      ..where((t) => t.id.equals(id)))
      .getSingleOrNull();
  }

  Stream<List<TransactionEntry>> watchTransactions() {
    return (_db.select(_db.transactionEntries)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
      .watch();
  }

  Future<void> insertTransaction(TransactionEntry entry) {
    return _db.into(_db.transactionEntries).insert(entry);
  }

  Future<void> updateTransaction(TransactionEntry entry) {
    return _db.update(_db.transactionEntries).replace(entry);
  }

  // Budgets
  Stream<List<BudgetEntry>> watchActiveBudgets() {
    return (_db.select(_db.budgetEntries)
      ..where((b) => b.isActive.equals(true)))
      .watch();
  }

  // Groups (Phase 2)
  Stream<List<GroupEntry>> watchGroups() {
    return (_db.select(_db.groupEntries)
      ..orderBy([(g) => OrderingTerm.desc(g.updatedAt)]))
      .watch();
  }

  // ... other queries
}
```

### Mappers

```dart
// transaction_mapper.dart
import '../../domain/entities/transaction.dart';
import 'package:airo_app/core/database/app_database.dart';

class TransactionMapper {
  Transaction toDomain(TransactionEntry entry) {
    return Transaction(
      id: entry.id,
      description: entry.description,
      amountCents: entry.amountCents,
      type: TransactionType.values[entry.typeIndex],
      categoryId: entry.categoryId,
      accountId: entry.accountId,
      transactionDate: entry.transactionDate,
      notes: entry.notes,
      receiptId: entry.receiptId,
      tags: entry.tags?.split(',') ?? [],
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      isDeleted: entry.isDeleted,
    );
  }

  TransactionEntry toEntry(Transaction domain) {
    return TransactionEntry(
      id: domain.id,
      description: domain.description,
      amountCents: domain.amountCents,
      typeIndex: domain.type.index,
      categoryId: domain.categoryId,
      accountId: domain.accountId,
      transactionDate: domain.transactionDate,
      notes: domain.notes,
      receiptId: domain.receiptId,
      tags: domain.tags.join(','),
      createdAt: domain.createdAt,
      updatedAt: domain.updatedAt,
      isDeleted: domain.isDeleted,
    );
  }
}
```

---

## Presentation Layer

The presentation layer contains UI components and screen logic.

### Screen Example

```dart
// coins_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/dashboard_providers.dart';
import '../widgets/budget/safe_to_spend_widget.dart';
import '../widgets/expense/expense_list_item.dart';

class CoinsDashboardScreen extends ConsumerWidget {
  const CoinsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safeToSpend = ref.watch(safeToSpendProvider);
    final recentExpenses = ref.watch(recentExpensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Coins')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardRefreshProvider.future),
        child: ListView(
          children: [
            // Safe to Spend Hero
            safeToSpend.when(
              data: (data) => SafeToSpendWidget(data: data),
              loading: () => const SafeToSpendSkeleton(),
              error: (e, _) => SafeToSpendError(error: e),
            ),

            // Recent Expenses
            const SectionHeader(title: 'Recent Expenses'),
            recentExpenses.when(
              data: (expenses) => ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: expenses.length,
                itemBuilder: (context, index) => ExpenseListItem(
                  expense: expenses[index],
                  onTap: () => _navigateToDetail(context, expenses[index]),
                ),
              ),
              loading: () => const ExpenseListSkeleton(),
              error: (e, _) => ExpenseListError(error: e),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddExpense(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

---

## Core Services Integration

### Integration Points

| Package | Usage in Coins | Files Affected |
|---------|---------------|----------------|
| `core_domain` | Entity base class, Result type, UseCase interface | All domain entities, repositories |
| `core_data` | AppDatabase, SyncService, EncryptionService | Data layer, datasources |
| `core_ui` | Theme tokens, shared widgets | All presentation widgets |
| `core_ai` | LLMClient, GemmaInference | Mind interface, receipt parsing |
| `core_auth` | AuthService, current user | Group management, expense ownership |

### Database Integration

The Coins feature extends the existing `AppDatabase` defined in `app/lib/core/database/app_database.dart`.

```dart
// Required table additions (database migration v4)
// Already defined in DOMAIN_API_CONTRACTS.md

// TransactionEntries - existing, enhanced
// BudgetEntries - existing, enhanced
// AccountEntries - existing
// GroupEntries - new
// GroupMemberEntries - new
// SharedExpenseEntries - new
// SplitEntries - new
// SettlementEntries - new
// ReceiptTextEntries - new
```

### AI Integration (Mind Interface)

```dart
// Integration with core_ai package
import 'package:core_ai/core_ai.dart';

final mindLlmProvider = Provider<LLMClient>((ref) {
  final router = ref.watch(llmRouterProvider);
  return router.getClient(
    preferOnDevice: true,  // Privacy-first
    modelHint: 'gemma-1b-int4',
  );
});

// Intent classification using on-device model
final intentClassifierProvider = Provider<IntentClassifier>((ref) {
  final llm = ref.watch(mindLlmProvider);
  return IntentClassifier(llm);
});
```

### Authentication Integration

```dart
// Integration with core_auth package
import 'package:core_auth/core_auth.dart';

final currentUserIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    authenticated: (user) => user.uid,
    orElse: () => throw UnauthorizedError(),
  );
});

// Used for expense ownership, group membership
final expenseOwnerProvider = Provider<String>((ref) {
  return ref.watch(currentUserIdProvider);
});
```

---

## Test Structure

```
app/test/features/coins/
├── domain/
│   ├── entities/
│   │   ├── transaction_test.dart
│   │   ├── budget_test.dart
│   │   └── group_test.dart
│   ├── services/
│   │   ├── budget_engine_test.dart
│   │   ├── balance_engine_test.dart
│   │   ├── split_calculator_test.dart
│   │   └── debt_simplifier_test.dart
│   └── repositories/
│       └── transaction_repository_test.dart (contract tests)
│
├── application/
│   ├── use_cases/
│   │   ├── add_expense_use_case_test.dart
│   │   ├── set_budget_use_case_test.dart
│   │   ├── create_group_use_case_test.dart
│   │   └── calculate_balances_use_case_test.dart
│   └── providers/
│       ├── expense_providers_test.dart
│       └── budget_providers_test.dart
│
├── data/
│   ├── repositories/
│   │   ├── transaction_repository_impl_test.dart
│   │   └── group_repository_impl_test.dart
│   └── mappers/
│       ├── transaction_mapper_test.dart
│       └── group_mapper_test.dart
│
├── presentation/
│   ├── screens/
│   │   ├── coins_dashboard_screen_test.dart
│   │   └── add_expense_screen_test.dart
│   └── widgets/
│       ├── safe_to_spend_widget_test.dart
│       └── expense_list_item_test.dart
│
├── mind/
│   ├── domain/
│   │   └── services/
│   │       ├── intent_classifier_test.dart
│   │       └── entity_extractor_test.dart
│   └── application/
│       └── use_cases/
│           └── process_input_use_case_test.dart
│
├── receipt/
│   ├── domain/
│   │   └── services/
│   │       ├── receipt_image_preprocessor_test.dart
│   │       └── gemma_receipt_parser_test.dart
│   └── application/
│       └── use_cases/
│           └── process_receipt_use_case_test.dart
│
├── fixtures/                           # Test data
│   ├── transactions.json
│   ├── budgets.json
│   ├── groups.json
│   └── receipts/
│       ├── sample_receipt_1.jpg
│       └── sample_receipt_2.jpg
│
└── mocks/                              # Mock implementations
    ├── mock_transaction_repository.dart
    ├── mock_budget_repository.dart
    ├── mock_group_repository.dart
    ├── mock_llm_client.dart
    └── mock_coins_local_datasource.dart
```

### Test Patterns

```dart
// Example: Budget Engine Unit Test
import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/coins/domain/services/budget_engine.dart';

void main() {
  late BudgetEngineImpl engine;

  setUp(() {
    engine = BudgetEngineImpl();
  });

  group('calculateSafeToSpend', () {
    test('returns correct amount when budget is 50% spent', () {
      final budget = Budget(
        id: '1',
        categoryId: 'food',
        limitCents: 10000, // ₹100
        period: BudgetPeriod.monthly,
        startDate: DateTime(2026, 2, 1),
      );

      final transactions = [
        Transaction(amountCents: 5000, transactionDate: DateTime(2026, 2, 10)),
      ];

      final result = engine.calculateSafeToSpend(
        budgets: [budget],
        transactions: transactions,
        currentDate: DateTime(2026, 2, 15),
      );

      expect(result.amountCents, equals(5000)); // ₹50 remaining
      expect(result.percentUsed, equals(50));
      expect(result.daysRemaining, equals(13));
    });
  });
}
```

---

## Dependencies

### pubspec.yaml additions

```yaml
dependencies:
  # Core packages
  core_domain:
    path: ../packages/core_domain
  core_data:
    path: ../packages/core_data
  core_ui:
    path: ../packages/core_ui
  core_ai:
    path: ../packages/core_ai
  core_auth:
    path: ../packages/core_auth

  # State management
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0

  # Database
  drift: ^2.14.0

  # ML Kit (OCR)
  google_mlkit_text_recognition: ^0.11.0

  # Image processing
  image: ^4.1.0

  # Camera
  camera: ^0.10.5

  # Utilities
  equatable: ^2.0.5
  uuid: ^4.2.1
  intl: ^0.19.0

dev_dependencies:
  # Testing
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0

  # Code generation
  riverpod_generator: ^2.3.0
  build_runner: ^2.4.0
  drift_dev: ^2.14.0
```

---

## Barrel Export

The public API for the Coins feature is exported through `coins.dart`:

```dart
// coins.dart
/// Coins feature - AI-native money management
library coins;

// Domain - Entities
export 'domain/entities/transaction.dart';
export 'domain/entities/budget.dart';
export 'domain/entities/account.dart';
export 'domain/entities/category.dart';
export 'domain/entities/group.dart';
export 'domain/entities/shared_expense.dart';
export 'domain/entities/settlement.dart';

// Domain - Models
export 'domain/models/safe_to_spend.dart';
export 'domain/models/budget_status.dart';
export 'domain/models/balance_summary.dart';
export 'domain/models/currency.dart';

// Domain - Repository Interfaces
export 'domain/repositories/transaction_repository.dart';
export 'domain/repositories/budget_repository.dart';
export 'domain/repositories/group_repository.dart';

// Domain - Services
export 'domain/services/budget_engine.dart';
export 'domain/services/balance_engine.dart';

// Application - Providers
export 'application/providers/expense_providers.dart';
export 'application/providers/budget_providers.dart';
export 'application/providers/group_providers.dart';
export 'application/providers/dashboard_providers.dart';

// Presentation - Screens
export 'presentation/screens/dashboard/coins_dashboard_screen.dart';
export 'presentation/screens/expense/add_expense_screen.dart';
export 'presentation/screens/budget/budget_overview_screen.dart';
export 'presentation/screens/group/group_list_screen.dart';

// Presentation - Widgets (commonly reused)
export 'presentation/widgets/common/amount_display.dart';
export 'presentation/widgets/budget/safe_to_spend_widget.dart';
export 'presentation/widgets/group/group_card.dart';

// Mind Interface (Phase 3)
export 'mind/presentation/screens/mind_screen.dart';

// Receipt OCR (Phase 3)
export 'receipt/presentation/screens/receipt_scan_screen.dart';
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-15 | AI Assistant | Initial structure documentation |

---

## Related Documents

- [TDD_MIND_INTERFACE.md](./TDD_MIND_INTERFACE.md) - Mind Interface technical design
- [TDD_OCR_RECEIPT_PROCESSING.md](./TDD_OCR_RECEIPT_PROCESSING.md) - OCR pipeline technical design
- [DOMAIN_API_CONTRACTS.md](./DOMAIN_API_CONTRACTS.md) - Domain layer API contracts
- [UI_WIREFRAMES.md](./UI_WIREFRAMES.md) - UI wireframes and screen specifications
- [ENGINEERING_TICKETS_PHASE_1.md](./ENGINEERING_TICKETS_PHASE_1.md) - Phase 1 engineering tickets
- [ENGINEERING_TICKETS_PHASE_2.md](./ENGINEERING_TICKETS_PHASE_2.md) - Phase 2 engineering tickets
```

