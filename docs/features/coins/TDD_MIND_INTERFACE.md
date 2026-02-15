# Technical Design Document: Mind Interface Component

## Document Information

| Field | Value |
|-------|-------|
| **Feature** | Coins - Mind Conversational Interface |
| **Author** | Airo Engineering Team |
| **Status** | Draft |
| **Created** | 2026-02-15 |
| **Last Updated** | 2026-02-15 |

---

## 1. Overview

### 1.1 Purpose

The Mind Interface is a conversational AI component that allows users to interact with the Coins financial management system using natural language. Users can log expenses, query balances, create splits, and get financial insights through chat-based interactions.

### 1.2 Goals

- Enable natural language expense logging (< 3 seconds end-to-end)
- Support financial queries with contextual understanding
- Integrate seamlessly with existing `core_ai` package
- Maintain 100% on-device processing for privacy
- Achieve ≥ 92% intent classification accuracy

### 1.3 Non-Goals

- General-purpose chatbot functionality
- Financial advisory recommendations (Phase 2)
- Voice-first interface (Phase 2)
- Multi-turn complex conversations (initial release)

---

## 2. Architecture

### 2.1 High-Level Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Mind Interface Layer                          │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐  │
│  │   Chat UI   │  │   Intent    │  │   Entity    │  │  Action    │  │
│  │  Component  │──│  Classifier │──│  Extractor  │──│  Executor  │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └────────────┘  │
│         │                │                │               │          │
│         ▼                ▼                ▼               ▼          │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    Mind Service Layer                        │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐  │    │
│  │  │PromptBuilder │  │ResponseParser│  │ConfirmationEngine│  │    │
│  │  └──────────────┘  └──────────────┘  └───────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Core AI Package                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐   │
│  │  LLMRouter   │  │ GeminiNano   │  │   GGUFModelClient        │   │
│  │              │  │    Client    │  │                          │   │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Coins Domain Layer                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐   │
│  │ Transaction  │  │   Budget     │  │     Split/Group          │   │
│  │  Repository  │  │  Repository  │  │     Repository           │   │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Integration with Existing Packages

| Package | Integration Point | Purpose |
|---------|------------------|---------|
| `core_ai` | `LLMRouter`, `LLMClient` | Route prompts to appropriate model |
| `core_ai` | `GeminiNanoClient` | On-device inference |
| `core_domain` | `Result<T>` | Functional error handling |
| `core_domain` | `UseCase<I,O>` | Business logic encapsulation |
| `core_data` | `SyncService` | Offline-first sync |
| `core_auth` | `AuthService` | User context |

---

## 3. Intent Classification System

### 3.1 Supported Intents

| Intent | Confidence Threshold | Example Utterances |
|--------|---------------------|-------------------|
| `ADD_EXPENSE` | 0.85 | "Spent 450 on Uber", "Paid 200 for coffee" |
| `ADD_SPLIT` | 0.85 | "Paid 2000 split with Rohan", "Dinner 1500 divide equally" |
| `QUERY_BALANCE` | 0.80 | "Who owes me?", "What's my balance with Arjun?" |
| `QUERY_SPENDING` | 0.80 | "How much on food this week?", "Total spend today" |
| `QUERY_BUDGET` | 0.80 | "Am I within budget?", "How much can I spend?" |
| `ADD_INVESTMENT` | 0.85 | "Add 5k SIP", "Invested 10000 in mutual fund" |
| `ADD_SUBSCRIPTION` | 0.85 | "Netflix 199 monthly", "Added Spotify subscription" |
| `DAILY_SUMMARY` | 0.75 | "Summarize today", "What happened today?" |
| `SETTLE_UP` | 0.85 | "Settle with Arjun", "Clear balance" |
| `UNDO` | 0.90 | "Undo", "Cancel that", "Remove last" |
| `HELP` | 0.70 | "Help", "What can you do?" |
| `UNKNOWN` | < 0.70 | Fallback for unrecognized intents |

### 3.2 Intent Classification Architecture

```dart
/// Intent classification result
class IntentResult {
  final MindIntent intent;
  final double confidence;
  final Map<String, dynamic> metadata;
  
  bool get isConfident => confidence >= intent.threshold;
}

/// Supported Mind intents
enum MindIntent {
  addExpense(0.85),
  addSplit(0.85),
  queryBalance(0.80),
  querySpending(0.80),
  queryBudget(0.80),
  addInvestment(0.85),
  addSubscription(0.85),
  dailySummary(0.75),
  settleUp(0.85),
  undo(0.90),
  help(0.70),
  unknown(0.0);

  final double threshold;
  const MindIntent(this.threshold);
}
```

### 3.3 Classification Prompt Template

```
You are a financial intent classifier. Classify the user's message into exactly one intent.

Available intents:
- ADD_EXPENSE: User wants to log a personal expense
- ADD_SPLIT: User wants to log a shared expense with others
- QUERY_BALANCE: User asks about who owes them or they owe
- QUERY_SPENDING: User asks about spending amounts by category/time
- QUERY_BUDGET: User asks about budget status
- ADD_INVESTMENT: User wants to log an investment
- ADD_SUBSCRIPTION: User wants to log a recurring subscription
- DAILY_SUMMARY: User wants a summary of financial activity
- SETTLE_UP: User wants to settle balances with someone
- UNDO: User wants to undo the last action
- HELP: User needs help with the app
- UNKNOWN: Cannot determine intent

User message: "{user_input}"

Respond with JSON only:
{"intent": "INTENT_NAME", "confidence": 0.XX}
```

---

## 4. Entity Extraction Pipeline

### 4.1 Entity Types

| Entity | Type | Examples | Required For |
|--------|------|----------|--------------|
| `amount` | Integer (paise) | "450", "₹1,200", "2k" | ADD_EXPENSE, ADD_SPLIT |
| `category` | String (enum) | "food", "transport", "shopping" | ADD_EXPENSE |
| `person` | String[] | "Rohan", "Arjun and Priya" | ADD_SPLIT, QUERY_BALANCE |
| `date` | DateTime | "today", "yesterday", "15th" | All intents |
| `time_range` | DateRange | "this week", "last month" | QUERY_SPENDING |
| `description` | String | "Uber ride", "dinner at Social" | ADD_EXPENSE |
| `split_type` | Enum | "equal", "percentage", "exact" | ADD_SPLIT |
| `currency` | Enum | "INR", "USD" | All intents |

### 4.2 Entity Extraction Model

```dart
/// Extracted entities from user input
class ExtractedEntities {
  final int? amountPaise;
  final String? category;
  final List<String> people;
  final DateTime? date;
  final DateRange? timeRange;
  final String? description;
  final SplitType? splitType;
  final Currency currency;
  final double confidence;

  const ExtractedEntities({
    this.amountPaise,
    this.category,
    this.people = const [],
    this.date,
    this.timeRange,
    this.description,
    this.splitType,
    this.currency = Currency.inr,
    this.confidence = 0.0,
  });

  /// Check if required entities are present for intent
  bool hasRequiredEntities(MindIntent intent) {
    switch (intent) {
      case MindIntent.addExpense:
        return amountPaise != null;
      case MindIntent.addSplit:
        return amountPaise != null && people.isNotEmpty;
      case MindIntent.queryBalance:
        return true; // Optional: specific person
      case MindIntent.querySpending:
        return true; // Optional: category, timeRange
      default:
        return true;
    }
  }
}
```

### 4.3 Entity Extraction Prompt Template

```
Extract financial entities from this message. Be precise with amounts.

User message: "{user_input}"

Rules:
- Convert amounts to paise (multiply by 100): "450" → 45000, "2k" → 200000
- Detect currency: default INR if not specified
- Extract all person names mentioned
- Infer category from context: food, transport, shopping, bills, entertainment, health, other
- Parse relative dates: "today" → current date, "yesterday" → current date - 1

Respond with JSON only:
{
  "amount_paise": 45000,
  "category": "transport",
  "people": ["Rohan"],
  "date": "2026-02-15",
  "description": "Uber ride",
  "split_type": "equal",
  "currency": "INR",
  "confidence": 0.92
}
```

---

## 5. Action Execution Engine

### 5.1 Action Flow

```
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  Parse Input  │───▶│ Build Action  │───▶│   Validate    │
│               │    │    Object     │    │    Action     │
└───────────────┘    └───────────────┘    └───────────────┘
                                                 │
                                                 ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│    Persist    │◀───│    Execute    │◀───│   Confirm     │
│   to Storage  │    │    Action     │    │  (if needed)  │
└───────────────┘    └───────────────┘    └───────────────┘
                           │
                           ▼
                    ┌───────────────┐
                    │   Generate    │
                    │   Response    │
                    └───────────────┘
```

### 5.2 Action Types

```dart
/// Base action class
sealed class MindAction {
  final String id;
  final DateTime timestamp;
  final bool requiresConfirmation;

  const MindAction({
    required this.id,
    required this.timestamp,
    this.requiresConfirmation = true,
  });
}

/// Add expense action
class AddExpenseAction extends MindAction {
  final int amountPaise;
  final String category;
  final String? description;
  final DateTime date;

  const AddExpenseAction({
    required super.id,
    required super.timestamp,
    required this.amountPaise,
    required this.category,
    this.description,
    required this.date,
  });
}

/// Add split action
class AddSplitAction extends MindAction {
  final int amountPaise;
  final List<String> participants;
  final SplitType splitType;
  final String? groupId;
  final String? description;

  const AddSplitAction({
    required super.id,
    required super.timestamp,
    required this.amountPaise,
    required this.participants,
    required this.splitType,
    this.groupId,
    this.description,
    super.requiresConfirmation = true,
  });
}

/// Query action (no confirmation needed)
class QueryAction extends MindAction {
  final QueryType queryType;
  final Map<String, dynamic> parameters;

  const QueryAction({
    required super.id,
    required super.timestamp,
    required this.queryType,
    required this.parameters,
  }) : super(requiresConfirmation: false);
}

enum QueryType { balance, spending, budget, summary }
```

### 5.3 Confirmation Engine

```dart
/// Confirmation card shown to user before executing action
class ConfirmationCard {
  final MindAction action;
  final String title;
  final List<ConfirmationField> fields;
  final List<String> warnings;

  const ConfirmationCard({
    required this.action,
    required this.title,
    required this.fields,
    this.warnings = const [],
  });

  /// Generate confirmation card for action
  factory ConfirmationCard.fromAction(MindAction action) {
    return switch (action) {
      AddExpenseAction a => ConfirmationCard(
        action: a,
        title: 'Add Expense',
        fields: [
          ConfirmationField('Amount', '₹${(a.amountPaise / 100).toStringAsFixed(2)}'),
          ConfirmationField('Category', a.category),
          if (a.description != null) ConfirmationField('Description', a.description!),
          ConfirmationField('Date', _formatDate(a.date)),
        ],
      ),
      AddSplitAction a => ConfirmationCard(
        action: a,
        title: 'Split Expense',
        fields: [
          ConfirmationField('Amount', '₹${(a.amountPaise / 100).toStringAsFixed(2)}'),
          ConfirmationField('Split with', a.participants.join(', ')),
          ConfirmationField('Split type', a.splitType.name),
        ],
      ),
      _ => throw UnimplementedError(),
    };
  }
}

class ConfirmationField {
  final String label;
  final String value;
  final bool isEditable;

  const ConfirmationField(this.label, this.value, {this.isEditable = true});
}
```

---

## 6. State Management

### 6.1 Mind State Model

```dart
/// State for the Mind interface
@freezed
class MindState with _$MindState {
  const factory MindState({
    @Default([]) List<MindMessage> messages,
    @Default(false) bool isProcessing,
    MindAction? pendingAction,
    ConfirmationCard? pendingConfirmation,
    String? error,
    @Default([]) List<String> suggestions,
  }) = _MindState;
}

/// A message in the Mind conversation
@freezed
class MindMessage with _$MindMessage {
  const factory MindMessage.user({
    required String id,
    required String text,
    required DateTime timestamp,
  }) = UserMessage;

  const factory MindMessage.assistant({
    required String id,
    required String text,
    required DateTime timestamp,
    MindAction? action,
  }) = AssistantMessage;

  const factory MindMessage.confirmation({
    required String id,
    required ConfirmationCard card,
    required DateTime timestamp,
  }) = ConfirmationMessage;

  const factory MindMessage.result({
    required String id,
    required String text,
    required DateTime timestamp,
    required bool success,
  }) = ResultMessage;
}
```

### 6.2 Mind Notifier (Riverpod)

```dart
/// Provider for Mind state
final mindStateProvider = StateNotifierProvider<MindNotifier, MindState>((ref) {
  return MindNotifier(
    llmRouter: ref.watch(llmRouterProvider),
    transactionRepo: ref.watch(transactionRepositoryProvider),
    splitRepo: ref.watch(splitRepositoryProvider),
    budgetRepo: ref.watch(budgetRepositoryProvider),
  );
});

class MindNotifier extends StateNotifier<MindState> {
  final LLMRouter _llmRouter;
  final TransactionRepository _transactionRepo;
  final SplitRepository _splitRepo;
  final BudgetRepository _budgetRepo;

  MindNotifier({
    required LLMRouter llmRouter,
    required TransactionRepository transactionRepo,
    required SplitRepository splitRepo,
    required BudgetRepository budgetRepo,
  }) : _llmRouter = llmRouter,
       _transactionRepo = transactionRepo,
       _splitRepo = splitRepo,
       _budgetRepo = budgetRepo,
       super(const MindState());

  /// Process user input
  Future<void> processInput(String input) async {
    // Add user message
    final userMessage = MindMessage.user(
      id: _generateId(),
      text: input,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isProcessing: true,
      error: null,
    );

    try {
      // 1. Classify intent
      final intentResult = await _classifyIntent(input);

      // 2. Extract entities
      final entities = await _extractEntities(input, intentResult.intent);

      // 3. Build action
      final action = _buildAction(intentResult.intent, entities);

      // 4. Show confirmation or execute directly
      if (action.requiresConfirmation) {
        final card = ConfirmationCard.fromAction(action);
        state = state.copyWith(
          pendingAction: action,
          pendingConfirmation: card,
          isProcessing: false,
        );
      } else {
        await _executeAction(action);
      }
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isProcessing: false,
      );
    }
  }

  /// Confirm pending action
  Future<void> confirmAction() async {
    final action = state.pendingAction;
    if (action == null) return;

    state = state.copyWith(isProcessing: true);
    await _executeAction(action);
    state = state.copyWith(
      pendingAction: null,
      pendingConfirmation: null,
    );
  }

  /// Cancel pending action
  void cancelAction() {
    state = state.copyWith(
      pendingAction: null,
      pendingConfirmation: null,
    );
  }

  /// Undo last action
  Future<void> undoLastAction() async {
    // Implementation for undo
  }
}
```

---

## 7. Error Handling

### 7.1 Error Types

```dart
/// Mind-specific errors
sealed class MindError {
  final String message;
  final String? suggestion;

  const MindError(this.message, {this.suggestion});
}

class IntentNotRecognizedError extends MindError {
  const IntentNotRecognizedError()
    : super(
        "I didn't understand that.",
        suggestion: "Try saying 'Spent 500 on food' or 'Who owes me?'",
      );
}

class MissingEntityError extends MindError {
  final String entityType;

  const MissingEntityError(this.entityType)
    : super("I need more information.");

  @override
  String get suggestion => switch (entityType) {
    'amount' => "How much did you spend?",
    'person' => "Who should I split with?",
    'category' => "What category is this?",
    _ => "Can you provide more details?",
  };
}

class ActionFailedError extends MindError {
  final String actionType;

  const ActionFailedError(this.actionType, String message) : super(message);
}

class LLMUnavailableError extends MindError {
  const LLMUnavailableError()
    : super(
        "AI is temporarily unavailable.",
        suggestion: "Try again or use manual entry.",
      );
}
```

### 7.2 Error Recovery Flow

```
┌─────────────────┐
│  Error Occurs   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│  Recoverable?   │──No─▶│  Show Error +   │
│                 │      │  Manual Entry   │
└────────┬────────┘      └─────────────────┘
         │Yes
         ▼
┌─────────────────┐
│  Show Clarify   │
│    Question     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Retry with     │
│  Additional     │
│  Context        │
└─────────────────┘
```

---

## 8. Performance Requirements

| Metric | Target | Measurement |
|--------|--------|-------------|
| Intent classification latency | < 500ms | P95 |
| Entity extraction latency | < 800ms | P95 |
| Total response time | < 1.5s | P95 |
| Memory footprint | < 50MB | Peak during inference |
| Confirmation display | < 200ms | After processing |

---

## 9. Testing Strategy

### 9.1 Unit Tests

- Intent classifier accuracy: Test against 500+ labeled utterances
- Entity extractor accuracy: Test amount parsing, date parsing, person extraction
- Action builder: Test all intent-to-action mappings
- State management: Test state transitions

### 9.2 Integration Tests

- End-to-end flow: Input → Classification → Extraction → Action → Storage
- LLM integration: Test with actual Gemini Nano model
- Error recovery: Test all error paths

### 9.3 Accuracy Benchmarks

| Test Set | Size | Target Accuracy |
|----------|------|-----------------|
| Intent classification | 500 utterances | ≥ 92% |
| Entity extraction | 300 utterances | ≥ 88% |
| Amount parsing | 200 amounts | ≥ 95% |
| Date parsing | 100 dates | ≥ 90% |

---

## 10. Security Considerations

1. **On-device processing**: All LLM inference runs locally
2. **No chat logs synced**: Conversation history stays on device
3. **Action confirmation**: Sensitive actions require explicit confirmation
4. **Input sanitization**: Prevent prompt injection attacks
5. **Rate limiting**: Prevent abuse of AI inference

---

## 11. File Structure

```
app/lib/features/coins/
├── mind/
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
│           └── suggestion_chips.dart
```

---

## 12. Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `core_ai` | local | LLM router and clients |
| `core_domain` | local | Result types, use cases |
| `flutter_riverpod` | ^2.4.0 | State management |
| `freezed` | ^2.4.0 | Immutable models |
| `uuid` | ^4.0.0 | ID generation |

---

## 13. Open Questions

1. Should we support multi-turn clarification dialogues?
2. Voice input: Integrate with platform speech-to-text or use Gemini?
3. Should suggestions be context-aware based on user history?
4. How to handle ambiguous amounts (e.g., "a few hundred")?

---

**Document History**

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-02-15 | 1.0 | Airo Team | Initial draft |
```

