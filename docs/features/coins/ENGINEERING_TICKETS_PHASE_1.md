# Engineering Tickets: Coins Phase 1 (Foundation)

## Document Information

| Field | Value |
|-------|-------|
| **Feature** | Coins - Financial Management |
| **Phase** | 1 - Foundation |
| **Duration** | 4 weeks |
| **Total Story Points** | 89 |
| **Author** | Airo Engineering Team |
| **Created** | 2026-02-15 |

---

## Sprint Overview

| Sprint | Focus | Story Points | Duration |
|--------|-------|--------------|----------|
| Week 1 | Firebase Auth Integration | 21 | 5 days |
| Week 2 | Core Data Models | 23 | 5 days |
| Week 3 | Expense CRUD Screens | 24 | 5 days |
| Week 4 | Budget Calculator | 21 | 5 days |

---

## Dependency Diagram

```
                    ┌─────────────────────────┐
                    │   COINS-001            │
                    │   Firebase Auth Setup   │
                    └───────────┬─────────────┘
                                │
            ┌───────────────────┼───────────────────┐
            │                   │                   │
            ▼                   ▼                   ▼
┌─────────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   COINS-002        │ │  COINS-003      │ │  COINS-004      │
│   User Profile     │ │  Session Mgmt   │ │  Auth UI        │
└────────┬────────────┘ └────────┬────────┘ └────────┬────────┘
         │                       │                   │
         └───────────────────────┼───────────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │   COINS-005            │
                    │   Database Schema v4   │
                    └───────────┬─────────────┘
                                │
         ┌──────────────────────┼──────────────────────┐
         │                      │                      │
         ▼                      ▼                      ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  COINS-006     │  │  COINS-007      │  │  COINS-008      │
│  Repositories  │  │  Transaction    │  │  Budget Entity  │
│                │  │  Entity         │  │                 │
└────────┬───────┘  └────────┬────────┘  └────────┬────────┘
         │                   │                    │
         └───────────────────┼────────────────────┘
                             │
                             ▼
              ┌──────────────────────────┐
              │      COINS-009          │
              │   Add Expense Screen    │
              └──────────────┬───────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  COINS-010     │ │  COINS-011      │ │  COINS-012      │
│  Expense List  │ │  Quick Add      │ │  Categories     │
└────────┬───────┘ └────────┬────────┘ └────────┬────────┘
         │                  │                   │
         └──────────────────┼───────────────────┘
                            │
                            ▼
             ┌──────────────────────────┐
             │      COINS-013          │
             │   Budget Setup Screen   │
             └──────────────┬───────────┘
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
         ▼                  ▼                  ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  COINS-014     │ │  COINS-015      │ │  COINS-016      │
│  Budget Engine │ │  Safe-to-Spend  │ │  Dashboard      │
└────────────────┘ └─────────────────┘ └─────────────────┘
```

---

## Week 1: Firebase Auth Integration (21 pts)

### COINS-001: Setup Firebase Auth for Coins Module

| Field | Value |
|-------|-------|
| **Type** | Technical |
| **Points** | 5 |
| **Assignee** | Backend Developer |
| **Labels** | `auth`, `firebase`, `foundation` |
| **Priority** | P0 - Critical |

**Description**

Integrate Firebase Authentication into the Coins module, extending the existing `core_auth` package. This will enable secure user authentication using Google Sign-In and email/password.

**Acceptance Criteria**

- [ ] Firebase project configured with Android/iOS apps
- [ ] `google-services.json` and `GoogleService-Info.plist` added
- [ ] Firebase Auth SDK integrated
- [ ] FirebaseAuthService implements AuthService interface from `core_auth`
- [ ] Google Sign-In flow working on Android and iOS
- [ ] Email/password sign-in working
- [ ] Auth state persisted across app restarts
- [ ] Unit tests for auth service (≥80% coverage)

**Technical Notes**

```dart
// Extend existing core_auth interface
class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  @override
  Future<Result<User>> signInWithGoogle() async { ... }
  
  @override
  Future<Result<User>> signInWithEmail(String email, String password) async { ... }
  
  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges().map(_mapUser);
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/data/auth/firebase_auth_service.dart`
- Create: `app/lib/features/coins/data/auth/firebase_user_mapper.dart`
- Modify: `android/app/google-services.json`
- Modify: `ios/Runner/GoogleService-Info.plist`
- Modify: `pubspec.yaml` (add firebase_auth, google_sign_in)

**Dependencies**

- `core_auth` package
- Firebase project setup

---

### COINS-002: User Profile Data Model

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 5 |
| **Assignee** | Backend Developer |
| **Labels** | `auth`, `data-model`, `foundation` |
| **Priority** | P0 - Critical |

**Description**

Create user profile data model and repository to store user-specific settings and preferences for the Coins feature.

**Acceptance Criteria**

- [ ] UserProfile entity created with required fields
- [ ] UserProfileRepository interface defined
- [ ] Local storage implementation using Drift
- [ ] Profile syncs with Firebase user data
- [ ] Default currency preference stored
- [ ] Avatar URL synced from Google account
- [ ] Unit tests for repository (≥80% coverage)

**Technical Notes**

```dart
class UserProfile extends Entity {
  final String email;
  final String displayName;
  final String? avatarUrl;
  final Currency preferredCurrency;
  final String? defaultAccountId;
  final DateTime createdAt;
  final DateTime lastActiveAt;
}

abstract class UserProfileRepository extends Repository<UserProfile> {
  Future<Result<UserProfile>> findByUserId(String userId);
  Future<Result<void>> updatePreferences(String userId, Map<String, dynamic> prefs);
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/domain/entities/user_profile.dart`
- Create: `app/lib/features/coins/domain/repositories/user_profile_repository.dart`
- Create: `app/lib/features/coins/data/repositories/user_profile_repository_impl.dart`
- Modify: `app/lib/core/database/app_database.dart` (add UserProfileEntries table)

**Dependencies**

- COINS-001 (Firebase Auth Setup)

---

### COINS-003: Session Management & Token Refresh

| Field | Value |
|-------|-------|
| **Type** | Technical |
| **Points** | 5 |
| **Assignee** | Backend Developer |
| **Labels** | `auth`, `security`, `foundation` |
| **Priority** | P0 - Critical |

**Description**

Implement secure session management including token refresh, secure storage, and automatic re-authentication.

**Acceptance Criteria**

- [ ] Firebase ID tokens stored securely
- [ ] Automatic token refresh before expiry
- [ ] Session timeout handling (configurable)
- [ ] Secure logout with token revocation
- [ ] Biometric lock option for app re-entry
- [ ] Session persistence across app restarts
- [ ] Handle network errors during refresh

**Technical Notes**

```dart
class SessionManager {
  final FlutterSecureStorage _secureStorage;
  final FirebaseAuth _auth;

  Future<String?> getValidToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // Force refresh if token expires in < 5 mins
    return user.getIdToken(forceRefresh: _shouldRefresh());
  }

  Future<void> secureLogout() async {
    await _auth.signOut();
    await _secureStorage.deleteAll();
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/data/auth/session_manager.dart`
- Create: `app/lib/features/coins/data/auth/secure_token_storage.dart`
- Modify: `app/lib/features/coins/application/providers/auth_providers.dart`

**Dependencies**

- COINS-001 (Firebase Auth Setup)

---

### COINS-004: Authentication UI Screens

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 6 |
| **Assignee** | Frontend Developer |
| **Labels** | `ui`, `auth`, `foundation` |
| **Priority** | P0 - Critical |

**Description**

Create authentication UI screens following the Airo design system, including login, signup, and password reset flows.

**Acceptance Criteria**

- [ ] Login screen with Google Sign-In and email/password
- [ ] Sign-up screen with email verification
- [ ] Forgot password screen with reset email
- [ ] Loading states during auth operations
- [ ] Error handling with user-friendly messages
- [ ] Responsive design for all screen sizes
- [ ] Follows `core_ui` design tokens and components
- [ ] Animation for screen transitions
- [ ] Widget tests for all screens

**Technical Notes**

```dart
// Using existing core_ui components
class LoginScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: authState.when(
        loading: () => const AiroLoadingIndicator(),
        authenticated: (_) => const SizedBox.shrink(), // Auto-redirect
        unauthenticated: () => _buildLoginForm(context, ref),
        error: (e) => _buildErrorState(e),
      ),
    );
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/presentation/screens/auth/login_screen.dart`
- Create: `app/lib/features/coins/presentation/screens/auth/signup_screen.dart`
- Create: `app/lib/features/coins/presentation/screens/auth/forgot_password_screen.dart`
- Create: `app/lib/features/coins/presentation/widgets/auth/google_sign_in_button.dart`
- Create: `app/lib/features/coins/presentation/widgets/auth/auth_form_field.dart`

**Dependencies**

- COINS-001 (Firebase Auth Setup)
- `core_ui` package

---

## Week 2: Core Data Models (23 pts)

### COINS-005: Database Schema v4 Migration

| Field | Value |
|-------|-------|
| **Type** | Technical |
| **Points** | 8 |
| **Assignee** | Backend Developer |
| **Labels** | `database`, `migration`, `foundation` |
| **Priority** | P0 - Critical |

**Description**

Extend the existing `app_database.dart` (v3) to v4 with new tables for Coins feature: groups, expenses, splits, settlements, subscriptions, and investments.

**Acceptance Criteria**

- [ ] All new tables created as per DOMAIN_API_CONTRACTS.md
- [ ] Migration from v3 to v4 implemented and tested
- [ ] All indexes created for query performance
- [ ] Foreign key relationships properly defined
- [ ] Soft delete column added to TransactionEntries
- [ ] Receipt text search table created
- [ ] Migration tested on fresh install
- [ ] Migration tested on upgrade from v3
- [ ] Schema documentation updated

**Technical Notes**

```dart
@DriftDatabase(
  tables: [
    // Existing tables
    TransactionEntries,
    BudgetEntries,
    AccountEntries,
    OutboxEntries,
    SyncMetadata,
    // New tables for v4
    GroupEntries,
    GroupMemberEntries,
    SharedExpenseEntries,
    SplitEntries,
    SettlementEntries,
    SubscriptionEntries,
    InvestmentEntries,
    ReceiptTextEntries,
    UserProfileEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 4) {
        // v4 migration - see DOMAIN_API_CONTRACTS.md
      }
    },
  );
}
```

**Files to Create/Modify**

- Modify: `app/lib/core/database/app_database.dart`
- Create: `app/lib/core/database/tables/group_tables.dart`
- Create: `app/lib/core/database/tables/split_tables.dart`
- Create: `app/lib/core/database/tables/subscription_tables.dart`
- Create: `app/lib/core/database/tables/investment_tables.dart`
- Run: `flutter pub run build_runner build`

**Dependencies**

- COINS-001 through COINS-004 (Week 1 completion)

---

### COINS-006: Repository Implementations

| Field | Value |
|-------|-------|
| **Type** | Technical |
| **Points** | 5 |
| **Assignee** | Backend Developer |
| **Labels** | `data`, `repository`, `foundation` |
| **Priority** | P0 - Critical |

**Description**

Implement repository classes for Transaction and Budget entities, following the patterns in `core_domain`.

**Acceptance Criteria**

- [ ] TransactionRepository implementation with all methods
- [ ] BudgetRepository implementation with all methods
- [ ] AccountRepository implementation
- [ ] Proper error handling with Result type
- [ ] Query optimization with proper WHERE clauses
- [ ] Pagination support for large datasets
- [ ] Unit tests for all repository methods (≥85% coverage)

**Technical Notes**

```dart
class TransactionRepositoryImpl implements TransactionRepository {
  final AppDatabase _db;

  @override
  Future<Result<List<Transaction>>> findByDateRange(
    DateTime start,
    DateTime end, {
    String? accountId,
    String? category,
  }) async {
    try {
      final query = _db.select(_db.transactionEntries)
        ..where((t) => t.timestamp.isBetweenValues(start, end))
        ..where((t) => t.deletedAt.isNull());

      if (accountId != null) {
        query.where((t) => t.accountId.equals(accountId));
      }
      if (category != null) {
        query.where((t) => t.category.equals(category));
      }

      final results = await query.get();
      return Result.ok(results.map(_mapToEntity).toList());
    } catch (e) {
      return Result.err(DatabaseError(e.toString()));
    }
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/data/repositories/transaction_repository_impl.dart`
- Create: `app/lib/features/coins/data/repositories/budget_repository_impl.dart`
- Create: `app/lib/features/coins/data/repositories/account_repository_impl.dart`
- Create: `app/lib/features/coins/data/mappers/transaction_mapper.dart`
- Create: `app/lib/features/coins/data/mappers/budget_mapper.dart`

**Dependencies**

- COINS-005 (Database Schema v4)

---

### COINS-007: Transaction Entity & Use Cases

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 5 |
| **Assignee** | Backend Developer |
| **Labels** | `domain`, `use-case`, `foundation` |
| **Priority** | P0 - Critical |

**Description**

Create Transaction domain entity and implement core use cases for expense/income management.

**Acceptance Criteria**

- [ ] Transaction entity with all required fields
- [ ] AddExpenseUseCase implemented
- [ ] AddIncomeUseCase implemented
- [ ] GetTransactionsUseCase with filtering
- [ ] DeleteTransactionUseCase (soft delete)
- [ ] UndoDeleteUseCase for recovery
- [ ] Validation rules enforced
- [ ] Unit tests for all use cases

**Technical Notes**

```dart
// Following core_domain UseCase pattern
class AddExpenseUseCase implements UseCase<AddExpenseInput, Transaction> {
  final TransactionRepository _transactionRepo;
  final BudgetRepository _budgetRepo;

  @override
  Future<Result<Transaction>> call(AddExpenseInput input) async {
    // 1. Validate
    final validation = input.validate();
    if (validation.isErr) return Result.err(validation.error);

    // 2. Create transaction (negative amount for expense)
    final tx = Transaction(
      id: uuid.v4(),
      amountCents: -input.amountPaise,
      // ...
    );

    // 3. Save and update budget
    final saved = await _transactionRepo.save(tx);
    if (saved.isOk) {
      await _budgetRepo.updateUtilization(input.category, input.amountPaise);
    }

    return saved;
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/domain/entities/transaction.dart`
- Create: `app/lib/features/coins/domain/use_cases/add_expense_use_case.dart`
- Create: `app/lib/features/coins/domain/use_cases/add_income_use_case.dart`
- Create: `app/lib/features/coins/domain/use_cases/get_transactions_use_case.dart`
- Create: `app/lib/features/coins/domain/use_cases/delete_transaction_use_case.dart`

**Dependencies**

- COINS-006 (Repository Implementations)

---

### COINS-008: Budget Entity & Validation

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 5 |
| **Assignee** | Backend Developer |
| **Labels** | `domain`, `budget`, `foundation` |
| **Priority** | P1 - High |

**Description**

Create Budget domain entity with validation rules and utilization tracking.

**Acceptance Criteria**

- [ ] Budget entity with all fields from DOMAIN_API_CONTRACTS
- [ ] Validation for budget limits (positive amounts only)
- [ ] Period month format validation (YYYYMM)
- [ ] Carryover logic for unused budget
- [ ] Utilization calculation methods
- [ ] Budget exceeded detection
- [ ] Unit tests for entity and validation

**Technical Notes**

```dart
class Budget extends Entity {
  final String category;
  final int limitCents;
  final int usedCents;
  final int carryoverCents;
  final int periodMonth; // YYYYMM
  final Recurrence recurrence;
  final CarryoverBehavior carryoverBehavior;

  int get remainingCents => limitCents + carryoverCents - usedCents;

  double get utilizationPercent =>
    limitCents > 0 ? (usedCents / limitCents) * 100 : 0;

  bool get isOverBudget => usedCents > limitCents + carryoverCents;

  bool get isApproachingLimit => utilizationPercent >= 80;

  Result<void> validate() {
    if (limitCents <= 0) {
      return Result.err(ValidationError('limit', 'Budget limit must be positive'));
    }
    if (periodMonth < 202001 || periodMonth > 209912) {
      return Result.err(ValidationError('period', 'Invalid period month'));
    }
    return Result.ok(null);
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/domain/entities/budget.dart`
- Create: `app/lib/features/coins/domain/value_objects/period_month.dart`
- Create: `app/lib/features/coins/domain/value_objects/recurrence.dart`
- Modify: `app/lib/features/coins/data/mappers/budget_mapper.dart`

**Dependencies**

- COINS-006 (Repository Implementations)

---

## Week 3: Expense CRUD Screens (24 pts)

### COINS-009: Add Expense Screen

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 8 |
| **Assignee** | Frontend Developer |
| **Labels** | `ui`, `expense`, `crud` |
| **Priority** | P0 - Critical |

**Description**

Create the primary Add Expense screen with full form, category selection, and optional receipt attachment.

**Acceptance Criteria**

- [ ] Amount input with currency formatting
- [ ] Category picker with icons
- [ ] Date picker defaulting to today
- [ ] Description input with auto-suggestions
- [ ] Account selector (if multiple accounts)
- [ ] Receipt attachment button (photo/gallery)
- [ ] Tags input with autocomplete
- [ ] Form validation with error messages
- [ ] Loading state during save
- [ ] Success feedback with undo option
- [ ] Widget tests for all interactions

**Technical Notes**

```dart
class AddExpenseScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final addExpenseState = ref.watch(addExpenseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AmountInputField(controller: _amountController),
            const SizedBox(height: 16),
            CategoryPicker(
              onSelected: (cat) => setState(() => _category = cat),
            ),
            // ... more fields
          ],
        ),
      ),
    );
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/presentation/screens/expense/add_expense_screen.dart`
- Create: `app/lib/features/coins/presentation/widgets/expense/amount_input_field.dart`
- Create: `app/lib/features/coins/presentation/widgets/expense/category_picker.dart`
- Create: `app/lib/features/coins/presentation/widgets/expense/receipt_attach_button.dart`
- Create: `app/lib/features/coins/application/providers/expense_providers.dart`

**Dependencies**

- COINS-007 (Transaction Entity & Use Cases)
- `core_ui` package

---

### COINS-010: Expense List Screen

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 6 |
| **Assignee** | Frontend Developer |
| **Labels** | `ui`, `expense`, `list` |
| **Priority** | P0 - Critical |

**Description**

Create the expense list screen with grouping by date, filtering, and search functionality.

**Acceptance Criteria**

- [ ] List grouped by date (Today, Yesterday, This Week, etc.)
- [ ] Each item shows amount, category icon, description
- [ ] Pull-to-refresh functionality
- [ ] Infinite scroll pagination
- [ ] Filter by category, date range
- [ ] Search by description
- [ ] Swipe to delete with undo
- [ ] Tap to view/edit expense
- [ ] Empty state with CTA
- [ ] Widget tests

**Technical Notes**

```dart
class ExpenseListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context, ref),
          ),
        ],
      ),
      body: expenses.when(
        data: (list) => _buildList(list),
        loading: () => const AiroShimmerList(),
        error: (e, _) => AiroErrorWidget(error: e),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/coins/expense/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/presentation/screens/expense/expense_list_screen.dart`
- Create: `app/lib/features/coins/presentation/widgets/expense/expense_list_item.dart`
- Create: `app/lib/features/coins/presentation/widgets/expense/expense_filter_sheet.dart`
- Create: `app/lib/features/coins/presentation/widgets/expense/date_group_header.dart`
- Modify: `app/lib/features/coins/application/providers/expense_providers.dart`

**Dependencies**

- COINS-009 (Add Expense Screen)

---

### COINS-011: Quick Add Expense Widget

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 5 |
| **Assignee** | Frontend Developer |
| **Labels** | `ui`, `expense`, `quick-add` |
| **Priority** | P1 - High |

**Description**

Create a quick-add widget for rapidly logging expenses with minimal input (amount + category only).

**Acceptance Criteria**

- [ ] Minimal UI with just amount and category
- [ ] Calculator-style number pad
- [ ] Quick category grid (8 most used)
- [ ] One-tap add with haptic feedback
- [ ] Optional description (expandable)
- [ ] Auto-dismiss after successful add
- [ ] Can be launched from notification action
- [ ] Can be embedded as bottom sheet
- [ ] Widget tests

**Technical Notes**

```dart
class QuickAddExpenseSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AmountDisplay(controller: _amountController),
          const SizedBox(height: 16),
          NumberPad(
            onDigit: _addDigit,
            onDelete: _deleteDigit,
            onClear: _clear,
          ),
          const SizedBox(height: 16),
          QuickCategoryGrid(
            categories: ref.watch(topCategoriesProvider),
            onSelected: _addExpense,
          ),
        ],
      ),
    );
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/presentation/widgets/expense/quick_add_expense_sheet.dart`
- Create: `app/lib/features/coins/presentation/widgets/common/number_pad.dart`
- Create: `app/lib/features/coins/presentation/widgets/common/amount_display.dart`
- Create: `app/lib/features/coins/presentation/widgets/expense/quick_category_grid.dart`

**Dependencies**

- COINS-009 (Add Expense Screen)

---

### COINS-012: Category Management

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 5 |
| **Assignee** | Frontend Developer |
| **Labels** | `ui`, `category`, `settings` |
| **Priority** | P1 - High |

**Description**

Create category management system with predefined categories and custom category support.

**Acceptance Criteria**

- [ ] Predefined categories with icons and colors
- [ ] Custom category creation
- [ ] Category icon picker
- [ ] Category color picker
- [ ] Reorder categories by drag-and-drop
- [ ] Hide/show categories
- [ ] Category usage statistics
- [ ] Persist order and visibility preferences
- [ ] Unit tests for category service

**Technical Notes**

```dart
// Predefined categories
enum ExpenseCategory {
  food('Food & Dining', Icons.restaurant, Color(0xFFE57373)),
  transport('Transport', Icons.directions_car, Color(0xFF64B5F6)),
  shopping('Shopping', Icons.shopping_bag, Color(0xFFBA68C8)),
  bills('Bills', Icons.receipt_long, Color(0xFFFFB74D)),
  entertainment('Entertainment', Icons.movie, Color(0xFF4FC3F7)),
  health('Health', Icons.local_hospital, Color(0xFF81C784)),
  groceries('Groceries', Icons.local_grocery_store, Color(0xFFA1887F)),
  travel('Travel', Icons.flight, Color(0xFF7986CB)),
  education('Education', Icons.school, Color(0xFF4DB6AC)),
  other('Other', Icons.more_horiz, Color(0xFF90A4AE));

  final String label;
  final IconData icon;
  final Color color;

  const ExpenseCategory(this.label, this.icon, this.color);
}

class CategoryService {
  Future<List<Category>> getOrderedCategories();
  Future<void> saveOrder(List<String> categoryIds);
  Future<Category> createCustomCategory(String name, IconData icon, Color color);
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/domain/entities/category.dart`
- Create: `app/lib/features/coins/domain/services/category_service.dart`
- Create: `app/lib/features/coins/presentation/screens/settings/category_management_screen.dart`
- Create: `app/lib/features/coins/presentation/widgets/category/category_icon_picker.dart`
- Create: `app/lib/features/coins/presentation/widgets/category/category_color_picker.dart`

**Dependencies**

- COINS-009 (Add Expense Screen)

---

## Week 4: Budget Calculator (21 pts)

### COINS-013: Budget Setup Screen

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 6 |
| **Assignee** | Frontend Developer |
| **Labels** | `ui`, `budget`, `setup` |
| **Priority** | P0 - Critical |

**Description**

Create budget setup screen for defining monthly budgets per category.

**Acceptance Criteria**

- [ ] List all categories with budget input
- [ ] Total budget display
- [ ] Individual category budget sliders
- [ ] Percentage vs. fixed amount toggle
- [ ] Copy from previous month option
- [ ] Reset to default budgets
- [ ] Validation that total doesn't exceed income
- [ ] Save and apply budgets
- [ ] Widget tests

**Technical Notes**

```dart
class BudgetSetupScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends ConsumerState<BudgetSetupScreen> {
  final Map<String, int> _budgets = {};

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Budget'),
        actions: [
          TextButton(
            onPressed: _saveBudgets,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return BudgetCategoryTile(
            category: category,
            budget: _budgets[category.id] ?? 0,
            onChanged: (value) => setState(() => _budgets[category.id] = value),
          );
        },
      ),
    );
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/presentation/screens/budget/budget_setup_screen.dart`
- Create: `app/lib/features/coins/presentation/widgets/budget/budget_category_tile.dart`
- Create: `app/lib/features/coins/presentation/widgets/budget/budget_slider.dart`
- Create: `app/lib/features/coins/presentation/widgets/budget/budget_total_header.dart`
- Create: `app/lib/features/coins/application/providers/budget_providers.dart`

**Dependencies**

- COINS-008 (Budget Entity & Validation)

---

### COINS-014: Budget Calculation Engine

| Field | Value |
|-------|-------|
| **Type** | Technical |
| **Points** | 5 |
| **Assignee** | Backend Developer |
| **Labels** | `domain`, `budget`, `engine` |
| **Priority** | P0 - Critical |

**Description**

Implement the budget calculation engine including utilization tracking, alerts, and projections.

**Acceptance Criteria**

- [ ] Track budget utilization in real-time
- [ ] Calculate remaining budget per category
- [ ] Calculate safe-to-spend daily amount
- [ ] Detect approaching limit (80% threshold)
- [ ] Detect exceeded budget
- [ ] Project month-end spending based on pace
- [ ] Carryover calculation for unused budget
- [ ] Unit tests with various scenarios

**Technical Notes**

```dart
class BudgetEngine {
  final BudgetRepository _budgetRepo;
  final TransactionRepository _transactionRepo;

  /// Calculate budget status for category
  Future<BudgetStatus> getStatus(String category, int periodMonth) async {
    final budget = await _budgetRepo.findByCategoryAndPeriod(category, periodMonth);
    final spending = await _getSpendingForPeriod(category, periodMonth);

    return BudgetStatus(
      budget: budget.value,
      spent: spending,
      remaining: budget.value.limitCents - spending,
      utilizationPercent: (spending / budget.value.limitCents) * 100,
      status: _determineStatus(spending, budget.value.limitCents),
      projectedTotal: _projectMonthEnd(spending, periodMonth),
    );
  }

  BudgetStatusType _determineStatus(int spent, int limit) {
    final pct = (spent / limit) * 100;
    if (pct >= 100) return BudgetStatusType.exceeded;
    if (pct >= 80) return BudgetStatusType.warning;
    return BudgetStatusType.onTrack;
  }
}

enum BudgetStatusType { onTrack, warning, exceeded }
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/domain/services/budget_engine.dart`
- Create: `app/lib/features/coins/domain/models/budget_status.dart`
- Create: `app/lib/features/coins/domain/use_cases/get_budget_status_use_case.dart`
- Create: `app/lib/features/coins/domain/use_cases/calculate_safe_to_spend_use_case.dart`

**Dependencies**

- COINS-008 (Budget Entity & Validation)
- COINS-006 (Repository Implementations)

---

### COINS-015: Safe-to-Spend Widget

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 5 |
| **Assignee** | Frontend Developer |
| **Labels** | `ui`, `budget`, `widget` |
| **Priority** | P0 - Critical |

**Description**

Create the safe-to-spend widget that shows daily spending allowance based on budget.

**Acceptance Criteria**

- [ ] Display daily safe-to-spend amount prominently
- [ ] Show remaining days in period
- [ ] Color coding: green (on track), yellow (warning), red (exceeded)
- [ ] Animated progress ring
- [ ] Tap to see breakdown by category
- [ ] Show comparison to yesterday
- [ ] Update in real-time after new expense
- [ ] Widget tests

**Technical Notes**

```dart
class SafeToSpendWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safeToSpend = ref.watch(safeToSpendProvider);

    return safeToSpend.when(
      data: (data) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Safe to spend today',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '₹${(data.dailyLimit / 100).toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: _getColor(data),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              CircularProgressIndicator(
                value: data.utilizationPercent / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(_getColor(data)),
              ),
              const SizedBox(height: 8),
              Text('${data.remainingDays} days left'),
            ],
          ),
        ),
      ),
      loading: () => const SafeToSpendShimmer(),
      error: (e, _) => ErrorWidget(e),
    );
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/presentation/widgets/budget/safe_to_spend_widget.dart`
- Create: `app/lib/features/coins/presentation/widgets/budget/safe_to_spend_shimmer.dart`
- Create: `app/lib/features/coins/presentation/widgets/budget/budget_breakdown_sheet.dart`
- Modify: `app/lib/features/coins/application/providers/budget_providers.dart`

**Dependencies**

- COINS-014 (Budget Calculation Engine)

---

### COINS-016: Coins Dashboard Screen

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 5 |
| **Assignee** | Frontend Developer |
| **Labels** | `ui`, `dashboard`, `home` |
| **Priority** | P0 - Critical |

**Description**

Create the main Coins dashboard that brings together safe-to-spend, recent expenses, and budget overview.

**Acceptance Criteria**

- [ ] Safe-to-spend widget at top
- [ ] Recent expenses list (last 5)
- [ ] Budget overview cards per category
- [ ] Quick add FAB
- [ ] Pull-to-refresh
- [ ] Navigation to all sub-screens
- [ ] Empty states for new users
- [ ] Onboarding prompt if no budget set
- [ ] Widget tests

**Technical Notes**

```dart
class CoinsDashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coins'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/coins/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardDataProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SafeToSpendWidget(),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Recent Expenses',
              onSeeAll: () => context.push('/coins/expenses'),
            ),
            const RecentExpensesList(limit: 5),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Budget Overview',
              onSeeAll: () => context.push('/coins/budget'),
            ),
            const BudgetOverviewGrid(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickAdd(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/presentation/screens/dashboard/coins_dashboard_screen.dart`
- Create: `app/lib/features/coins/presentation/widgets/dashboard/recent_expenses_list.dart`
- Create: `app/lib/features/coins/presentation/widgets/dashboard/budget_overview_grid.dart`
- Create: `app/lib/features/coins/presentation/widgets/dashboard/section_header.dart`
- Create: `app/lib/features/coins/application/providers/dashboard_providers.dart`

**Dependencies**

- COINS-010 (Expense List Screen)
- COINS-015 (Safe-to-Spend Widget)

---

## Testing Requirements

### Unit Test Coverage Targets

| Component | Target Coverage |
|-----------|-----------------|
| Repositories | ≥ 85% |
| Use Cases | ≥ 90% |
| Domain Entities | ≥ 95% |
| Services | ≥ 85% |

### Widget Test Requirements

- All screens must have widget tests
- Test loading, success, and error states
- Test user interactions (taps, swipes, input)
- Test validation error display

### Integration Test Scenarios

| Scenario | Priority |
|----------|----------|
| Complete expense add flow | P0 |
| Budget setup and utilization | P0 |
| Authentication flow | P0 |
| Offline expense add | P1 |
| Data sync after connectivity | P1 |

---

## Definition of Done

- [ ] Code reviewed and approved
- [ ] Unit tests written and passing (≥ target coverage)
- [ ] Widget tests written and passing
- [ ] No lint warnings or errors
- [ ] Documentation updated
- [ ] Accessibility requirements met
- [ ] Works on Android and iOS
- [ ] Manual QA sign-off

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Firebase quota limits | Low | Medium | Monitor usage, implement batching |
| Database migration issues | Medium | High | Test migration on real data |
| Performance with large datasets | Low | Medium | Pagination, indexing |
| On-device storage limits | Low | Low | Implement data cleanup policy |

---

## Summary

| Metric | Value |
|--------|-------|
| **Total Tickets** | 16 |
| **Total Story Points** | 89 |
| **Duration** | 4 weeks |
| **Team Size** | 2 (1 FE, 1 BE) |
| **Velocity Required** | ~22 pts/week |

---

**Document History**

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-02-15 | 1.0 | Airo Team | Initial draft |

