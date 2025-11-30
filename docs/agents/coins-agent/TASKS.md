# Coins Agent Tasks

**Context**: Repo has coins/finance module for tracking expenses and budgets.
**Goal**: Implement save expense, home transactions listing, budget deduction flow, and budget CRUD.
**Branch**: `agent/coins/expenses-and-budget`

## Tasks (ordered)

### 1. Save Expense (1h) - [x] DONE
- [x] Create Drift database schema for transactions with offline-outbox
  - `app/lib/core/database/app_database.dart` - TransactionEntries, BudgetEntries, AccountEntries tables
- [x] Implement `LocalTransactionsRepository` with DB persistence
  - `app/lib/features/money/data/repositories/local_transactions_repository.dart`
- [x] Add `syncStatus` enum (pending, synced, failed)
  - In `app_database.dart` with SyncStatus enum
- [x] Add unit tests for repository
  - `app/test/features/money/expense_service_test.dart`

### 2. Home Transactions Listing (1h) - [x] DONE
- [x] Add stream-backed paginated transactions provider
  - `transactionsStreamProvider` in `money_provider.dart`
- [x] Update Money overview screen with real transactions list
  - Updated `money_overview_screen.dart` to use stream provider
- [x] Add empty state placeholder when no transactions
  - Added nice empty state with icon and CTA button
- [x] Ensure efficient DB queries with pagination
  - `watchTransactions()` method with limit parameter

### 3. Budget Deduct on Expense (1h) - [x] DONE
- [x] On saving expense, deduct from active budget transactionally
  - `ExpenseService.saveExpense()` handles this
- [x] Handle negative balance (allow but mark as exceeded)
  - `BudgetDeductionStatus.exceededLimit` status returned
- [x] Add unit tests for budget deduction logic
  - Tests in `expense_service_test.dart` and `budget_repository_test.dart`

### 4. Budget CRUD (1-2h) - [x] DONE
- [x] Create/Update/Delete budgets UI screens
  - `app/lib/features/money/presentation/screens/budgets_screen.dart`
- [x] Implement budget repository methods with Drift
  - `app/lib/features/money/data/repositories/local_budgets_repository.dart`
- [x] Add validation (positive amounts in UI form)
- [x] Add tests
  - `app/test/features/money/budget_repository_test.dart`

## Run / Commands

```bash
# Local CI
act

# Flutter tests
cd app && flutter test

# Melos tests (if available)
melos run test

# Migration check
cd app && flutter pub run build_runner build
```

## Files Created/Modified

### Core Utilities
- `app/lib/core/database/app_database.dart` - Drift database with encryption support, indexes, migrations
- `app/lib/core/utils/sanitizer.dart` - Input sanitization for security
- `app/lib/core/utils/logger.dart` - Centralized logging with crash reporting hooks
- `app/lib/l10n/app_en.arb` - Localization strings (English)

### Money Feature Domain Layer
- `app/lib/features/money/domain/models/money_models.dart` - Enhanced Budget with carryover, recurrence
- `app/lib/features/money/domain/models/insight_models.dart` - Analytics data models
- `app/lib/features/money/domain/errors/money_errors.dart` - Typed error classes

### Money Feature Data Layer
- `app/lib/features/money/data/repositories/local_transactions_repository.dart` - DB-backed transactions
- `app/lib/features/money/data/repositories/local_budgets_repository.dart` - DB-backed budgets with validation, carryover

### Money Feature Application Layer
- `app/lib/features/money/application/services/expense_service.dart` - Transactional expense + budget deduction
- `app/lib/features/money/application/services/sync_service.dart` - Offline-outbox sync with retry logic
- `app/lib/features/money/application/services/insights_service.dart` - Analytics and spending insights
- `app/lib/features/money/application/providers/money_provider.dart` - All providers including insights, sync

### Money Feature Presentation Layer
- `app/lib/features/money/presentation/screens/add_expense_screen.dart` - Add expense UI
- `app/lib/features/money/presentation/screens/budgets_screen.dart` - Budget CRUD UI with accessibility
- `app/lib/features/money/presentation/screens/money_overview_screen.dart` - Updated home screen
- `app/lib/features/money/presentation/widgets/insights_dashboard.dart` - Analytics dashboard widget

### Tests
- `app/test/features/money/expense_service_test.dart` - Expense service unit tests
- `app/test/features/money/budget_repository_test.dart` - Budget repository tests with validation
- `app/test/features/money/budgets_screen_test.dart` - Widget tests for budgets screen
- `app/test/features/money/money_integration_test.dart` - Full integration tests

## Deliverables

- [x] TASKS.md updated with completion status
- [ ] PR with clear changelog of DB schema changes
- [ ] Migration steps documented
- [ ] Unit + widget tests passing

## Checks Before PR

- [ ] `act` green
- [x] DB encryption support added (SQLCipher-ready with DatabaseConfig)
- [x] No dropped user data risk (new tables, no migration from old data)
- [x] Migration rollback notes included below

## Production Features

### Security
- SQLCipher encryption support (enable via `DatabaseConfig.useEncryption`)
- Input sanitization for all text fields
- No sensitive data in logs in production

### Performance
- Database indexes on frequently queried columns
- WAL mode for better concurrent read/write
- Pagination support for large datasets
- Stream-backed reactive UI

### Offline-First
- All data stored locally first
- SyncStatus tracking (pending/synced/failed)
- Background sync service with retry logic
- Connectivity-aware sync triggers

### Observability
- Centralized logging with log levels
- Crash reporting hooks
- Performance metrics logging
- Analytics event tracking

### Accessibility
- Semantic labels on all interactive elements
- Screen reader support
- Proper focus management

### Localization
- ARB-based string externalization
- Ready for multi-language support

## DB Schema v2

```sql
CREATE TABLE transaction_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE NOT NULL,
  account_id TEXT NOT NULL,
  timestamp DATETIME NOT NULL,
  amount_cents INTEGER NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  tags TEXT DEFAULT '[]',
  receipt_url TEXT,
  sync_status TEXT DEFAULT 'pending',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME
);

-- Indexes for performance
CREATE INDEX idx_transactions_account ON transaction_entries(account_id);
CREATE INDEX idx_transactions_category ON transaction_entries(category);
CREATE INDEX idx_transactions_timestamp ON transaction_entries(timestamp DESC);

CREATE TABLE budget_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE NOT NULL,
  tag TEXT NOT NULL,
  limit_cents INTEGER NOT NULL,
  used_cents INTEGER DEFAULT 0,
  carryover_cents INTEGER DEFAULT 0,
  period_month INTEGER NOT NULL,
  recurrence TEXT DEFAULT 'monthly',
  carryover_behavior TEXT DEFAULT 'none',
  sync_status TEXT DEFAULT 'pending',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME
);

CREATE INDEX idx_budgets_period ON budget_entries(period_month, tag);

CREATE TABLE account_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  account_type TEXT NOT NULL,
  currency TEXT DEFAULT 'USD',
  balance_cents INTEGER DEFAULT 0,
  sync_status TEXT DEFAULT 'pending',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME
);
```

## Migration Notes

### Schema Version History
- **v1**: Initial schema with basic tables
- **v2**: Added indexes, carryover fields for budgets

### Rollback Procedure
```dart
// To rollback from v2 to v1:
// 1. Drop new indexes
await db.customStatement('DROP INDEX IF EXISTS idx_transactions_account');
await db.customStatement('DROP INDEX IF EXISTS idx_transactions_category');
await db.customStatement('DROP INDEX IF EXISTS idx_transactions_timestamp');
await db.customStatement('DROP INDEX IF EXISTS idx_budgets_period');

// 2. Remove carryover columns (requires table recreation in SQLite)
// Note: This will lose carryover data
```

### Data Safety
- All migrations are additive (no column removals)
- Indexes can be safely dropped without data loss
- Carryover columns have defaults, backward compatible
