# Engineering Tickets: Coins Phase 2 (Split Engine)

## Document Information

| Field | Value |
|-------|-------|
| **Feature** | Coins - Split Engine |
| **Phase** | 2 - Split Engine |
| **Duration** | 4 weeks |
| **Total Story Points** | 96 |
| **Author** | Airo Engineering Team |
| **Created** | 2026-02-15 |
| **Prerequisites** | Phase 1 Complete |

---

## Sprint Overview

| Sprint | Focus | Story Points | Duration |
|--------|-------|--------------|----------|
| Week 5 | Group Management | 24 | 5 days |
| Week 6 | Split Creation & Types | 26 | 5 days |
| Week 7 | Balance Calculation Engine | 24 | 5 days |
| Week 8 | Settlement & Payment Flow | 22 | 5 days |

---

## Dependency Diagram

```
                    ┌─────────────────────────┐
                    │   Phase 1 Complete      │
                    │   (COINS-001 to -016)   │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │   COINS-017            │
                    │   Group Data Model     │
                    └───────────┬─────────────┘
                                │
            ┌───────────────────┼───────────────────┐
            │                   │                   │
            ▼                   ▼                   ▼
┌─────────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   COINS-018        │ │  COINS-019      │ │  COINS-020      │
│   Group Repository │ │  Group CRUD UI  │ │  Member Mgmt    │
└────────┬───────────┘ └────────┬────────┘ └────────┬────────┘
         │                      │                   │
         └──────────────────────┼───────────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │   COINS-021            │
                    │   Split Data Model     │
                    └───────────┬─────────────┘
                                │
         ┌──────────────────────┼──────────────────────┐
         │                      │                      │
         ▼                      ▼                      ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  COINS-022     │  │  COINS-023      │  │  COINS-024      │
│  Split Types   │  │  Split Creation │  │  Split List UI  │
│  Engine        │  │  Screen         │  │                 │
└────────┬───────┘  └────────┬────────┘  └────────┬────────┘
         │                   │                    │
         └───────────────────┼────────────────────┘
                             │
                             ▼
              ┌──────────────────────────┐
              │      COINS-025          │
              │   Balance Calculator    │
              └──────────────┬───────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  COINS-026     │ │  COINS-027      │ │  COINS-028      │
│  Balance UI    │ │  Settlement     │ │  Payment        │
│  Dashboard     │ │  Engine         │ │  Request        │
└────────┬───────┘ └────────┬────────┘ └────────┬────────┘
         │                  │                   │
         └──────────────────┼───────────────────┘
                            │
                            ▼
             ┌──────────────────────────┐
             │      COINS-029          │
             │   Settlement History    │
             └──────────────┬───────────┘
                            │
                            ▼
             ┌──────────────────────────┐
             │      COINS-030          │
             │   Notification System   │
             └──────────────────────────┘
```

---

## Week 5: Group Management (24 pts)

### COINS-017: Group Data Model & Entity

| Field | Value |
|-------|-------|
| **Type** | Technical |
| **Points** | 6 |
| **Assignee** | Backend Developer |
| **Labels** | `domain`, `group`, `data-model` |
| **Priority** | P0 - Critical |

**Description**

Create the Group domain entity with full model including members, settings, and currency preferences.

**Acceptance Criteria**

- [ ] Group entity with all required fields (id, name, icon, currency, members)
- [ ] GroupMember entity with roles (admin, member)
- [ ] Group settings (simplify debts, default split type)
- [ ] Validation rules for group creation
- [ ] Support for multiple currencies per group
- [ ] Group invite code generation
- [ ] Unit tests for entity validation (≥95% coverage)

**Technical Notes**

```dart
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
  
  bool get isMultiCurrency => members.any((m) => m.currency != defaultCurrency);
  int get memberCount => members.length;
}

class GroupMember {
  final String id;
  final String userId;
  final String name;
  final String? avatarUrl;
  final MemberRole role;
  final Currency preferredCurrency;
  final DateTime joinedAt;
  
  bool get isAdmin => role == MemberRole.admin;
}

enum MemberRole { admin, member }

class GroupSettings {
  final bool simplifyDebts;
  final SplitType defaultSplitType;
  final bool allowSettlementReminders;
  final int reminderFrequencyDays;
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/domain/entities/group.dart`
- Create: `app/lib/features/coins/domain/entities/group_member.dart`
- Create: `app/lib/features/coins/domain/entities/group_settings.dart`
- Create: `app/lib/features/coins/domain/value_objects/member_role.dart`
- Modify: `app/lib/core/database/app_database.dart` (add GroupEntries, GroupMemberEntries)

**Dependencies**

- COINS-005 (Database Schema v4)
- Phase 1 Complete

---

### COINS-018: Group Repository & Use Cases

| Field | Value |
|-------|-------|
| **Type** | Technical |
| **Points** | 6 |
| **Assignee** | Backend Developer |
| **Labels** | `data`, `repository`, `group` |
| **Priority** | P0 - Critical |

**Description**

Implement GroupRepository with all CRUD operations and use cases for group management.

**Acceptance Criteria**

- [ ] GroupRepository interface implemented
- [ ] CreateGroupUseCase with validation
- [ ] UpdateGroupUseCase
- [ ] DeleteGroupUseCase (soft delete)
- [ ] AddMemberUseCase with invite handling
- [ ] RemoveMemberUseCase with balance check
- [ ] TransferAdminUseCase
- [ ] Proper error handling with Result type
- [ ] Unit tests (≥85% coverage)

**Technical Notes**

```dart
abstract class GroupRepository extends Repository<Group> {
  Future<Result<List<Group>>> findByUserId(String userId);
  Future<Result<Group>> findByInviteCode(String code);
  Future<Result<void>> addMember(String groupId, GroupMember member);
  Future<Result<void>> removeMember(String groupId, String memberId);
  Future<Result<void>> updateSettings(String groupId, GroupSettings settings);
  Future<Result<String>> generateInviteCode(String groupId);
}

class CreateGroupUseCase implements UseCase<CreateGroupInput, Group> {
  @override
  Future<Result<Group>> call(CreateGroupInput input) async {
    // 1. Validate group name (non-empty, max 50 chars)
    // 2. Generate unique ID
    // 3. Add creator as admin member
    // 4. Generate invite code
    // 5. Save to repository
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/domain/repositories/group_repository.dart`
- Create: `app/lib/features/coins/data/repositories/group_repository_impl.dart`
- Create: `app/lib/features/coins/domain/use_cases/create_group_use_case.dart`
- Create: `app/lib/features/coins/domain/use_cases/add_member_use_case.dart`
- Create: `app/lib/features/coins/domain/use_cases/remove_member_use_case.dart`
- Create: `app/lib/features/coins/data/mappers/group_mapper.dart`

**Dependencies**

- COINS-017 (Group Data Model)

---

### COINS-019: Group CRUD UI Screens

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 6 |
| **Assignee** | Frontend Developer |
| **Labels** | `ui`, `group`, `crud` |
| **Priority** | P0 - Critical |

**Description**

Create UI screens for group creation, viewing, and editing.

**Acceptance Criteria**

- [ ] Create Group screen with name, icon, currency selection
- [ ] Group Detail screen showing members and balances summary
- [ ] Edit Group screen for name, icon, settings
- [ ] Group settings screen (simplify debts, reminders)
- [ ] Group list screen with search and filter
- [ ] Empty state for no groups
- [ ] Loading and error states
- [ ] Responsive design for all screen sizes
- [ ] Widget tests for all screens

**Technical Notes**

```dart
class CreateGroupScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  String? _selectedIcon;
  Currency _currency = Currency.INR;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        actions: [
          TextButton(
            onPressed: _createGroup,
            child: const Text('Create'),
          ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: ResponsiveBreakpoints.formMaxWidth,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GroupIconPicker(
              selectedIcon: _selectedIcon,
              onSelected: (icon) => setState(() => _selectedIcon = icon),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Group Name'),
            ),
            // Currency picker, settings...
          ],
        ),
      ),
    );
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/presentation/screens/group/create_group_screen.dart`
- Create: `app/lib/features/coins/presentation/screens/group/group_detail_screen.dart`
- Create: `app/lib/features/coins/presentation/screens/group/edit_group_screen.dart`
- Create: `app/lib/features/coins/presentation/screens/group/group_list_screen.dart`
- Create: `app/lib/features/coins/presentation/widgets/group/group_icon_picker.dart`
- Create: `app/lib/features/coins/application/providers/group_providers.dart`

**Dependencies**

- COINS-018 (Group Repository)
- `core_ui` package

---

### COINS-020: Member Management UI

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 6 |
| **Assignee** | Frontend Developer |
| **Labels** | `ui`, `group`, `member` |
| **Priority** | P1 - High |

**Description**

Create UI for adding, removing, and managing group members including invite flow.

**Acceptance Criteria**

- [ ] Add member screen with contact picker
- [ ] Invite link generation and sharing
- [ ] Join group via invite code screen
- [ ] Member list with role indicators
- [ ] Remove member with confirmation
- [ ] Transfer admin role UI
- [ ] Member balance preview in list
- [ ] Contact permission handling
- [ ] Widget tests

**Technical Notes**

```dart
class MemberManagementScreen extends ConsumerWidget {
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(groupMembersProvider(groupId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final isAdmin = members.value?.any((m) =>
      m.userId == currentUserId && m.isAdmin) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _showAddMemberSheet(context),
            ),
        ],
      ),
      body: members.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) => MemberTile(
            member: list[i],
            isCurrentUser: list[i].userId == currentUserId,
            canManage: isAdmin && list[i].userId != currentUserId,
            onRemove: () => _removeMember(ref, list[i]),
          ),
        ),
        loading: () => const MemberListShimmer(),
        error: (e, _) => AiroErrorWidget(error: e),
      ),
    );
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/presentation/screens/group/member_management_screen.dart`
- Create: `app/lib/features/coins/presentation/screens/group/add_member_screen.dart`
- Create: `app/lib/features/coins/presentation/screens/group/join_group_screen.dart`
- Create: `app/lib/features/coins/presentation/widgets/group/member_tile.dart`
- Create: `app/lib/features/coins/presentation/widgets/group/invite_share_sheet.dart`
- Modify: `app/lib/features/coins/application/providers/group_providers.dart`

**Dependencies**

- COINS-019 (Group CRUD UI)
- Contact Service from `bill_split` feature

---

## Week 6: Split Creation & Types (26 pts)

### COINS-021: Split Data Model & Entity

| Field | Value |
|-------|-------|
| **Type** | Technical |
| **Points** | 6 |
| **Assignee** | Backend Developer |
| **Labels** | `domain`, `split`, `data-model` |
| **Priority** | P0 - Critical |

**Description**

Create the Split domain entity supporting multiple split types and expense tracking.

**Acceptance Criteria**

- [ ] Split entity with all required fields
- [ ] SharedExpense entity for group expenses
- [ ] SplitEntry entity for individual share tracking
- [ ] Support for equal, percentage, exact, and itemized splits
- [ ] Multi-currency split support
- [ ] Validation for split totals matching expense
- [ ] Unit tests (≥95% coverage)

**Technical Notes**

```dart
class SharedExpense extends Entity {
  final String groupId;
  final String description;
  final int totalAmountCents;
  final Currency currency;
  final String paidByUserId;
  final DateTime expenseDate;
  final String? category;
  final String? receiptUrl;
  final List<SplitEntry> splits;
  final SplitType splitType;
  final DateTime createdAt;
  final String createdBy;

  int get totalOwed => splits.fold(0, (sum, s) => sum + s.amountCents);
  bool get isBalanced => totalOwed == totalAmountCents;
}

class SplitEntry {
  final String id;
  final String expenseId;
  final String userId;
  final int amountCents;
  final double? percentage;
  final bool isPaid;
  final DateTime? paidAt;
}

enum SplitType {
  equal('Split Equally'),
  percentage('By Percentage'),
  exact('Exact Amounts'),
  itemized('By Items'),
  shares('By Shares');

  final String displayName;
  const SplitType(this.displayName);
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/domain/entities/shared_expense.dart`
- Create: `app/lib/features/coins/domain/entities/split_entry.dart`
- Create: `app/lib/features/coins/domain/value_objects/split_type.dart`
- Modify: `app/lib/core/database/app_database.dart` (add SharedExpenseEntries, SplitEntries)

**Dependencies**

- COINS-017 (Group Data Model)
- COINS-007 (Transaction Entity)

---

### COINS-022: Split Types Engine

| Field | Value |
|-------|-------|
| **Type** | Technical |
| **Points** | 8 |
| **Assignee** | Backend Developer |
| **Labels** | `domain`, `split`, `engine` |
| **Priority** | P0 - Critical |

**Description**

Implement the split calculation engine supporting all split types with validation.

**Acceptance Criteria**

- [ ] Equal split calculator
- [ ] Percentage split calculator with validation (must equal 100%)
- [ ] Exact amount split with remainder handling
- [ ] Itemized split with item-to-member assignment
- [ ] Shares-based split (2x, 3x multipliers)
- [ ] Rounding strategy (round up payer, round down others)
- [ ] Multi-currency conversion support
- [ ] Comprehensive unit tests for edge cases

**Technical Notes**

```dart
abstract class SplitCalculator {
  List<SplitEntry> calculate(int totalCents, List<String> memberIds);
}

class EqualSplitCalculator implements SplitCalculator {
  @override
  List<SplitEntry> calculate(int totalCents, List<String> memberIds) {
    final baseAmount = totalCents ~/ memberIds.length;
    final remainder = totalCents % memberIds.length;

    return memberIds.asMap().entries.map((e) {
      // First N members get +1 cent to handle remainder
      final extra = e.key < remainder ? 1 : 0;
      return SplitEntry(
        userId: e.value,
        amountCents: baseAmount + extra,
      );
    }).toList();
  }
}

class PercentageSplitCalculator implements SplitCalculator {
  final Map<String, double> percentages;

  List<SplitEntry> calculate(int totalCents, List<String> memberIds) {
    // Validate sum = 100%
    final sum = percentages.values.reduce((a, b) => a + b);
    if ((sum - 100.0).abs() > 0.01) {
      throw ValidationError('Percentages must sum to 100%');
    }
    // Calculate with rounding adjustment
  }
}

class ItemizedSplitCalculator implements SplitCalculator {
  final List<ItemAssignment> itemAssignments;

  // Each item assigned to one or more members
  // Calculate per-member total from their items
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/domain/services/split_calculator.dart`
- Create: `app/lib/features/coins/domain/services/equal_split_calculator.dart`
- Create: `app/lib/features/coins/domain/services/percentage_split_calculator.dart`
- Create: `app/lib/features/coins/domain/services/itemized_split_calculator.dart`
- Create: `app/lib/features/coins/domain/services/shares_split_calculator.dart`

**Dependencies**

- COINS-021 (Split Data Model)

---

### COINS-023: Split Creation Screen

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 8 |
| **Assignee** | Frontend Developer |
| **Labels** | `ui`, `split`, `creation` |
| **Priority** | P0 - Critical |

**Description**

Create the main split/expense creation screen with all split type options.

**Acceptance Criteria**

- [ ] Amount input with currency formatting
- [ ] Description input with suggestions
- [ ] "Paid by" selector (single or multiple payers)
- [ ] Split type selector (equal, percentage, exact, itemized)
- [ ] Dynamic UI based on selected split type
- [ ] Member selection with checkboxes
- [ ] Real-time split preview
- [ ] Validation errors for unbalanced splits
- [ ] Receipt attachment option
- [ ] Category picker
- [ ] Widget tests for all interactions

**Technical Notes**

```dart
class CreateSplitScreen extends ConsumerStatefulWidget {
  final String groupId;

  @override
  ConsumerState<CreateSplitScreen> createState() => _CreateSplitScreenState();
}

class _CreateSplitScreenState extends ConsumerState<CreateSplitScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  SplitType _splitType = SplitType.equal;
  String? _paidByUserId;
  Set<String> _selectedMembers = {};
  Map<String, int> _exactAmounts = {};
  Map<String, double> _percentages = {};

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(groupMembersProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: [
          TextButton(
            onPressed: _isValid ? _createSplit : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: ResponsiveBreakpoints.formMaxWidth,
        child: ListView(
          children: [
            AmountInputField(controller: _amountController),
            TextField(controller: _descriptionController),
            PaidBySelector(
              members: members.value ?? [],
              selectedId: _paidByUserId,
              onChanged: (id) => setState(() => _paidByUserId = id),
            ),
            SplitTypeSelector(
              selected: _splitType,
              onChanged: (type) => setState(() => _splitType = type),
            ),
            _buildSplitTypeUI(),
            SplitPreviewCard(
              total: _parsedAmount,
              splits: _calculatePreview(),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/presentation/screens/split/create_split_screen.dart`
- Create: `app/lib/features/coins/presentation/widgets/split/paid_by_selector.dart`
- Create: `app/lib/features/coins/presentation/widgets/split/split_type_selector.dart`
- Create: `app/lib/features/coins/presentation/widgets/split/equal_split_view.dart`
- Create: `app/lib/features/coins/presentation/widgets/split/percentage_split_view.dart`
- Create: `app/lib/features/coins/presentation/widgets/split/exact_split_view.dart`
- Create: `app/lib/features/coins/presentation/widgets/split/split_preview_card.dart`
- Create: `app/lib/features/coins/application/providers/split_providers.dart`

**Dependencies**

- COINS-022 (Split Types Engine)
- COINS-019 (Group CRUD UI)

---

### COINS-024: Split List & History UI

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 4 |
| **Assignee** | Frontend Developer |
| **Labels** | `ui`, `split`, `list` |
| **Priority** | P1 - High |

**Description**

Create the split/expense list view within a group showing history and filters.

**Acceptance Criteria**

- [ ] List of all group expenses chronologically
- [ ] Each item shows amount, description, paid by, date
- [ ] Visual indicator for who owes/is owed
- [ ] Filter by date range, category, member
- [ ] Search by description
- [ ] Swipe to delete (admin only)
- [ ] Tap to view/edit expense details
- [ ] Empty state
- [ ] Widget tests

**Technical Notes**

```dart
class SplitHistoryScreen extends ConsumerWidget {
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(groupExpensesProvider(groupId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: expenses.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) => SplitHistoryTile(
            expense: list[i],
            currentUserId: currentUserId,
            onTap: () => _viewExpenseDetail(list[i]),
          ),
        ),
        loading: () => const AiroShimmerList(),
        error: (e, _) => AiroErrorWidget(error: e),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/coins/group/$groupId/add-expense'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/presentation/screens/split/split_history_screen.dart`
- Create: `app/lib/features/coins/presentation/screens/split/expense_detail_screen.dart`
- Create: `app/lib/features/coins/presentation/widgets/split/split_history_tile.dart`
- Create: `app/lib/features/coins/presentation/widgets/split/expense_filter_sheet.dart`
- Modify: `app/lib/features/coins/application/providers/split_providers.dart`

**Dependencies**

- COINS-023 (Split Creation Screen)

---

## Week 7: Balance Calculation Engine (24 pts)

### COINS-025: Balance Calculation Engine

| Field | Value |
|-------|-------|
| **Type** | Technical |
| **Points** | 8 |
| **Assignee** | Backend Developer |
| **Labels** | `domain`, `balance`, `engine` |
| **Priority** | P0 - Critical |

**Description**

Implement the balance calculation engine with debt simplification algorithm.

**Acceptance Criteria**

- [ ] Calculate net balance per member (total owed - total owing)
- [ ] Generate pairwise debt matrix
- [ ] Implement debt simplification algorithm (minimize transactions)
- [ ] Support multi-currency balances with conversion
- [ ] Handle partial settlements
- [ ] Real-time balance updates on new expense
- [ ] Comprehensive unit tests for complex scenarios

**Technical Notes**

```dart
class BalanceEngine {
  final ExchangeRateService _exchangeService;

  /// Calculate net balances for all members
  Future<Map<String, int>> calculateNetBalances(
    String groupId,
    Currency targetCurrency,
  ) async {
    final expenses = await _getGroupExpenses(groupId);
    final settlements = await _getGroupSettlements(groupId);

    final balances = <String, int>{};

    for (final expense in expenses) {
      // Payer gains credit
      balances[expense.paidByUserId] =
        (balances[expense.paidByUserId] ?? 0) + expense.totalAmountCents;

      // Each split participant owes their share
      for (final split in expense.splits) {
        balances[split.userId] =
          (balances[split.userId] ?? 0) - split.amountCents;
      }
    }

    // Apply settlements
    for (final settlement in settlements) {
      balances[settlement.fromUserId] =
        (balances[settlement.fromUserId] ?? 0) + settlement.amountCents;
      balances[settlement.toUserId] =
        (balances[settlement.toUserId] ?? 0) - settlement.amountCents;
    }

    return balances;
  }

  /// Simplify debts using minimum cash flow algorithm
  List<SimplifiedDebt> simplifyDebts(Map<String, int> netBalances) {
    // Separate into creditors (positive) and debtors (negative)
    // Match largest debtor with largest creditor
    // Repeat until all settled
  }
}

class SimplifiedDebt {
  final String fromUserId;
  final String toUserId;
  final int amountCents;
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/domain/services/balance_engine.dart`
- Create: `app/lib/features/coins/domain/services/debt_simplifier.dart`
- Create: `app/lib/features/coins/domain/models/simplified_debt.dart`
- Create: `app/lib/features/coins/domain/services/exchange_rate_service.dart`
- Create: `app/lib/features/coins/domain/use_cases/calculate_balances_use_case.dart`

**Dependencies**

- COINS-021 (Split Data Model)
- COINS-022 (Split Types Engine)

---

### COINS-026: Balance Dashboard UI

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 6 |
| **Assignee** | Frontend Developer |
| **Labels** | `ui`, `balance`, `dashboard` |
| **Priority** | P0 - Critical |

**Description**

Create the balance dashboard showing who owes whom with simplified view.

**Acceptance Criteria**

- [ ] Overall balance summary card (you owe / you're owed)
- [ ] List of individual balances with each member
- [ ] Visual debt direction indicator (arrows)
- [ ] Color coding (red = you owe, green = owed to you)
- [ ] Toggle between simplified and detailed view
- [ ] Tap member to see transaction history with them
- [ ] "Settle Up" button per person
- [ ] Widget tests

**Technical Notes**

```dart
class BalanceDashboardScreen extends ConsumerWidget {
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(groupBalancesProvider(groupId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final simplify = ref.watch(simplifyDebtsSettingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Balances'),
        actions: [
          Switch(
            value: simplify,
            onChanged: (v) => ref.read(simplifyDebtsSettingProvider.notifier).state = v,
          ),
        ],
      ),
      body: balances.when(
        data: (data) => Column(
          children: [
            BalanceSummaryCard(
              totalOwed: data.totalOwed,
              totalOwing: data.totalOwing,
              netBalance: data.netBalance,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: data.memberBalances.length,
                itemBuilder: (_, i) {
                  final balance = data.memberBalances[i];
                  return MemberBalanceTile(
                    member: balance.member,
                    amount: balance.amount,
                    direction: balance.direction,
                    onSettleUp: () => _navigateToSettle(balance),
                  );
                },
              ),
            ),
          ],
        ),
        loading: () => const BalanceDashboardShimmer(),
        error: (e, _) => AiroErrorWidget(error: e),
      ),
    );
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/presentation/screens/balance/balance_dashboard_screen.dart`
- Create: `app/lib/features/coins/presentation/widgets/balance/balance_summary_card.dart`
- Create: `app/lib/features/coins/presentation/widgets/balance/member_balance_tile.dart`
- Create: `app/lib/features/coins/presentation/widgets/balance/balance_direction_indicator.dart`
- Create: `app/lib/features/coins/application/providers/balance_providers.dart`

**Dependencies**

- COINS-025 (Balance Calculation Engine)
- COINS-020 (Member Management UI)

---

### COINS-027: Settlement Engine

| Field | Value |
|-------|-------|
| **Type** | Technical |
| **Points** | 5 |
| **Assignee** | Backend Developer |
| **Labels** | `domain`, `settlement`, `engine` |
| **Priority** | P0 - Critical |

**Description**

Implement settlement tracking including partial settlements and settlement history.

**Acceptance Criteria**

- [ ] Settlement entity with all required fields
- [ ] SettlementRepository implementation
- [ ] CreateSettlementUseCase with validation
- [ ] Support partial settlements
- [ ] Settlement confirmation by recipient
- [ ] Auto-update balances on settlement
- [ ] Settlement reversal support
- [ ] Unit tests (≥85% coverage)

**Technical Notes**

```dart
class Settlement extends Entity {
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final int amountCents;
  final Currency currency;
  final SettlementMethod method;
  final SettlementStatus status;
  final String? note;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final String? paymentReference;
}

enum SettlementMethod {
  cash('Cash'),
  upi('UPI'),
  bankTransfer('Bank Transfer'),
  other('Other');

  final String displayName;
  const SettlementMethod(this.displayName);
}

enum SettlementStatus { pending, confirmed, rejected, reversed }

class CreateSettlementUseCase implements UseCase<CreateSettlementInput, Settlement> {
  @override
  Future<Result<Settlement>> call(CreateSettlementInput input) async {
    // 1. Validate amount <= total owed
    // 2. Create settlement record
    // 3. Update balances (pending until confirmed)
    // 4. Notify recipient
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/domain/entities/settlement.dart`
- Create: `app/lib/features/coins/domain/repositories/settlement_repository.dart`
- Create: `app/lib/features/coins/data/repositories/settlement_repository_impl.dart`
- Create: `app/lib/features/coins/domain/use_cases/create_settlement_use_case.dart`
- Create: `app/lib/features/coins/domain/use_cases/confirm_settlement_use_case.dart`

**Dependencies**

- COINS-025 (Balance Calculation Engine)

---

### COINS-028: Payment Request Generation

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 5 |
| **Assignee** | Backend Developer |
| **Labels** | `feature`, `payment`, `request` |
| **Priority** | P1 - High |

**Description**

Generate payment requests and shareable payment links for settlements.

**Acceptance Criteria**

- [ ] Generate UPI payment link with amount pre-filled
- [ ] Generate shareable text message with payment details
- [ ] QR code generation for payment
- [ ] Deep link to popular payment apps (GPay, PhonePe, Paytm)
- [ ] Payment confirmation tracking
- [ ] Reminder scheduling
- [ ] Unit tests

**Technical Notes**

```dart
class PaymentRequestService {
  /// Generate UPI intent URI
  String generateUpiLink({
    required String payeeVpa,
    required String payeeName,
    required int amountCents,
    required String transactionNote,
  }) {
    final amount = (amountCents / 100).toStringAsFixed(2);
    return 'upi://pay?pa=$payeeVpa&pn=${Uri.encodeComponent(payeeName)}'
           '&am=$amount&tn=${Uri.encodeComponent(transactionNote)}';
  }

  /// Generate shareable text
  String generateShareText(Settlement settlement, GroupMember payer, GroupMember payee) {
    final amount = formatCurrency(settlement.amountCents, settlement.currency);
    return '''
Hi ${payer.name}!

You owe $amount to ${payee.name} for expenses in "${settlement.groupName}".

Pay via UPI: ${payee.upiId ?? 'N/A'}

Settle up here: ${generateDeepLink(settlement)}
''';
  }

  /// Generate QR code data
  Future<Uint8List> generateQrCode(String upiLink) async {
    return QrPainter(data: upiLink).toImageData(200);
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/domain/services/payment_request_service.dart`
- Create: `app/lib/features/coins/domain/services/upi_link_generator.dart`
- Create: `app/lib/features/coins/domain/services/reminder_service.dart`
- Modify: `pubspec.yaml` (add qr_flutter package)

**Dependencies**

- COINS-027 (Settlement Engine)

---

## Week 8: Settlement & Payment Flow (22 pts)

### COINS-029: Settlement Flow UI

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 8 |
| **Assignee** | Frontend Developer |
| **Labels** | `ui`, `settlement`, `payment` |
| **Priority** | P0 - Critical |

**Description**

Create the complete settlement flow UI including payment, confirmation, and history.

**Acceptance Criteria**

- [ ] Settle Up screen with amount (editable for partial)
- [ ] Payment method selector
- [ ] Payment confirmation screen
- [ ] QR code display for payer
- [ ] Share payment request button
- [ ] Settlement history per group
- [ ] Settlement history per member
- [ ] Pending settlement notifications
- [ ] Widget tests

**Technical Notes**

```dart
class SettleUpScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String memberId;

  @override
  ConsumerState<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends ConsumerState<SettleUpScreen> {
  final _amountController = TextEditingController();
  SettlementMethod _method = SettlementMethod.upi;

  @override
  void initState() {
    super.initState();
    // Pre-fill with full amount owed
    final balance = ref.read(memberBalanceProvider(
      groupId: widget.groupId,
      memberId: widget.memberId,
    ));
    _amountController.text = formatAmount(balance.amountCents.abs());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settle Up')),
      body: ResponsiveCenter(
        maxWidth: ResponsiveBreakpoints.formMaxWidth,
        child: Column(
          children: [
            MemberAvatarHeader(memberId: widget.memberId),
            AmountInputField(
              controller: _amountController,
              label: 'Amount to settle',
            ),
            SettlementMethodPicker(
              selected: _method,
              onChanged: (m) => setState(() => _method = m),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _recordSettlement,
              child: const Text('Record Settlement'),
            ),
            TextButton(
              onPressed: _sharePaymentRequest,
              child: const Text('Share Payment Request'),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/presentation/screens/settlement/settle_up_screen.dart`
- Create: `app/lib/features/coins/presentation/screens/settlement/payment_confirmation_screen.dart`
- Create: `app/lib/features/coins/presentation/screens/settlement/settlement_history_screen.dart`
- Create: `app/lib/features/coins/presentation/widgets/settlement/settlement_method_picker.dart`
- Create: `app/lib/features/coins/presentation/widgets/settlement/payment_qr_card.dart`
- Create: `app/lib/features/coins/presentation/widgets/settlement/settlement_tile.dart`
- Create: `app/lib/features/coins/application/providers/settlement_providers.dart`

**Dependencies**

- COINS-027 (Settlement Engine)
- COINS-028 (Payment Request Generation)
- COINS-026 (Balance Dashboard UI)

---

### COINS-030: Notification System

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 6 |
| **Assignee** | Backend Developer |
| **Labels** | `feature`, `notification`, `reminder` |
| **Priority** | P1 - High |

**Description**

Implement local notification system for expense reminders, settlement requests, and daily summaries.

**Acceptance Criteria**

- [ ] Local notification service integration
- [ ] New expense notification to group members
- [ ] Settlement request notification
- [ ] Settlement confirmation notification
- [ ] Configurable reminder frequency
- [ ] Scheduled daily summary notification
- [ ] Notification preferences per group
- [ ] Deep linking from notifications
- [ ] Unit tests

**Technical Notes**

```dart
class CoinsNotificationService {
  final FlutterLocalNotificationsPlugin _notifications;

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
  }

  Future<void> showExpenseAdded({
    required String groupName,
    required String addedBy,
    required int amountCents,
    required String description,
  }) async {
    await _notifications.show(
      _generateId(),
      'New expense in $groupName',
      '$addedBy added ${formatCurrency(amountCents)}: $description',
      _expenseNotificationDetails,
      payload: 'expense:$expenseId',
    );
  }

  Future<void> scheduleSettlementReminder({
    required String groupId,
    required String memberId,
    required Duration delay,
  }) async {
    await _notifications.zonedSchedule(
      _generateId(),
      'Settlement Reminder',
      'You have pending settlements',
      tz.TZDateTime.now(tz.local).add(delay),
      _reminderNotificationDetails,
      payload: 'settle:$groupId:$memberId',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/domain/services/coins_notification_service.dart`
- Create: `app/lib/features/coins/presentation/screens/settings/notification_settings_screen.dart`
- Create: `app/lib/features/coins/application/providers/notification_providers.dart`
- Modify: `pubspec.yaml` (add flutter_local_notifications)

**Dependencies**

- COINS-027 (Settlement Engine)
- COINS-023 (Split Creation Screen)

---

### COINS-031: Group Activity Feed

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Points** | 4 |
| **Assignee** | Frontend Developer |
| **Labels** | `ui`, `activity`, `feed` |
| **Priority** | P2 - Medium |

**Description**

Create an activity feed showing all group activities in chronological order.

**Acceptance Criteria**

- [ ] Chronological activity list
- [ ] Activity types: expense added, settlement, member joined/left
- [ ] Activity detail on tap
- [ ] Filter by activity type
- [ ] Pull to refresh
- [ ] Infinite scroll pagination
- [ ] Widget tests

**Technical Notes**

```dart
sealed class GroupActivity {
  final String id;
  final DateTime timestamp;
  final String actorId;
}

class ExpenseActivity extends GroupActivity {
  final SharedExpense expense;
}

class SettlementActivity extends GroupActivity {
  final Settlement settlement;
}

class MemberActivity extends GroupActivity {
  final GroupMember member;
  final MemberActivityType type; // joined, left, roleChanged
}

class ActivityFeedScreen extends ConsumerWidget {
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(groupActivityFeedProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: activities.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) => ActivityTile(activity: list[i]),
        ),
        loading: () => const AiroShimmerList(),
        error: (e, _) => AiroErrorWidget(error: e),
      ),
    );
  }
}
```

**Files to Create/Modify**

- Create: `app/lib/features/coins/domain/models/group_activity.dart`
- Create: `app/lib/features/coins/presentation/screens/group/activity_feed_screen.dart`
- Create: `app/lib/features/coins/presentation/widgets/activity/activity_tile.dart`
- Create: `app/lib/features/coins/application/providers/activity_providers.dart`

**Dependencies**

- COINS-024 (Split List & History UI)
- COINS-029 (Settlement Flow UI)

---

### COINS-032: Phase 2 Integration Testing

| Field | Value |
|-------|-------|
| **Type** | Testing |
| **Points** | 4 |
| **Assignee** | QA Engineer |
| **Labels** | `testing`, `integration`, `e2e` |
| **Priority** | P0 - Critical |

**Description**

Create comprehensive integration tests for Phase 2 split engine functionality.

**Acceptance Criteria**

- [ ] E2E test: Create group → Add members → Add expense → Settle up
- [ ] E2E test: Multi-currency group with conversion
- [ ] E2E test: Debt simplification verification
- [ ] E2E test: Partial settlement flow
- [ ] E2E test: Itemized split creation
- [ ] Performance test: 100 expenses calculation < 500ms
- [ ] All tests pass on Android and iOS
- [ ] Test documentation updated

**Technical Notes**

```dart
void main() {
  patrolTest('Complete split flow', (PatrolIntegrationTester $) async {
    // Login
    await $.pumpWidgetAndSettle(const AiroApp());
    await $(#loginButton).tap();

    // Create group
    await $(#coinsTab).tap();
    await $(#createGroupButton).tap();
    await $(#groupNameField).enterText('Trip to Goa');
    await $(#createButton).tap();

    // Add expense
    await $(#addExpenseButton).tap();
    await $(#amountField).enterText('3000');
    await $(#descriptionField).enterText('Dinner');
    await $(#splitEquallyOption).tap();
    await $(#saveButton).tap();

    // Verify balances
    await $(#balancesTab).tap();
    expect($(#yourBalance), findsOneWidget);

    // Settle up
    await $(#settleUpButton).tap();
    await $(#recordSettlementButton).tap();

    // Verify settled
    expect($(#settledBadge), findsOneWidget);
  });
}
```

**Files to Create/Modify**

- Create: `app/integration_test/coins/split_flow_test.dart`
- Create: `app/integration_test/coins/balance_calculation_test.dart`
- Create: `app/integration_test/coins/settlement_flow_test.dart`
- Modify: `app/integration_test/test_config.dart`

**Dependencies**

- All Phase 2 tickets complete

---

## Testing Requirements

### Unit Test Coverage Targets

| Component | Target Coverage |
|-----------|-----------------|
| Balance Engine | ≥ 95% |
| Split Calculators | ≥ 95% |
| Repositories | ≥ 85% |
| Use Cases | ≥ 90% |
| Domain Entities | ≥ 95% |

### Integration Test Scenarios

| Scenario | Priority |
|----------|----------|
| Complete split flow (create → settle) | P0 |
| Multi-currency balance calculation | P0 |
| Debt simplification correctness | P0 |
| Partial settlement handling | P1 |
| Group member management | P1 |
| Notification delivery | P2 |

---

## Definition of Done

- [ ] Code reviewed and approved
- [ ] Unit tests written and passing (≥ target coverage)
- [ ] Widget tests written and passing
- [ ] Integration tests passing
- [ ] No lint warnings or errors
- [ ] Documentation updated
- [ ] Accessibility requirements met
- [ ] Works on Android and iOS
- [ ] Manual QA sign-off
- [ ] Performance benchmarks met

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Balance calculation edge cases | Medium | High | Extensive unit tests with edge cases |
| Multi-currency conversion accuracy | Medium | Medium | Use reliable exchange rate API |
| Debt simplification algorithm complexity | Low | Medium | Well-tested algorithm, fallback to unsimplified |
| Notification permission rejection | Medium | Low | Graceful degradation, in-app notifications |
| Large group performance | Low | Medium | Pagination, lazy loading, caching |

---

## Summary

| Metric | Value |
|--------|-------|
| **Total Tickets** | 16 |
| **Total Story Points** | 96 |
| **Duration** | 4 weeks |
| **Team Size** | 2 (1 FE, 1 BE) |
| **Velocity Required** | ~24 pts/week |

---

**Document History**

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-02-15 | 1.0 | Airo Team | Initial draft |

