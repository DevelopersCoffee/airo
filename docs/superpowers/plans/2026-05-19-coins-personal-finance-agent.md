# Coins Personal Finance Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a local, read-only personal finance assistant layer to Coins that turns existing transactions and budgets into actionable dashboard insights and `@Coins` chat guidance.

**Architecture:** Keep this first slice offline and deterministic. Add a pure domain service for insights, expose insight data through dashboard aggregation, and add a Coins agent tool that formats contextual finance guidance without connecting external accounts or moving money.

**Tech Stack:** Flutter, Dart, Riverpod, existing Coins domain entities, existing agent chat intent/tool registry.

---

## File Structure

- Create `app/lib/features/coins/domain/services/finance_insight_service.dart`: pure domain service that ranks recurring charges, budget risk, empty-state onboarding, and healthy-budget status.
- Create `app/test/features/coins/domain/services/finance_insight_service_test.dart`: unit tests for insight priority and message behavior.
- Modify `app/lib/features/coins/application/providers/dashboard_providers.dart`: add `financeInsights` to `DashboardData` and compute it from recent transactions and budget statuses.
- Modify `app/lib/features/coins/presentation/screens/coins_dashboard_screen.dart`: render a compact "Coins insights" dashboard section.
- Modify `app/lib/features/agent_chat/domain/services/intent_parser.dart`: add a `coinsQuestion` intent for `@Coins` and natural finance questions.
- Modify `app/lib/features/agent_chat/domain/services/tool_registry.dart`: add a `CoinsAgentTool` that gives a safe, contextual, read-only response.
- Create `app/test/features/agent_chat/domain/services/intent_parser_test.dart`: test parsing for `@Coins`.
- Create `app/test/features/agent_chat/domain/services/tool_registry_test.dart`: test the Coins agent response and safety wording.

## Tasks

### Task 1: Finance Insight Service

**Files:**
- Create: `app/lib/features/coins/domain/services/finance_insight_service.dart`
- Create: `app/test/features/coins/domain/services/finance_insight_service_test.dart`

- [ ] **Step 1: Write failing tests**

Create tests that assert recurring transactions produce a subscription-review insight, warning budgets produce a budget-risk insight, empty data asks the user to add an expense, and normal data reports healthy budget status.

- [ ] **Step 2: Run test to verify it fails**

Run: `/usr/bin/env flutter test test/features/coins/domain/services/finance_insight_service_test.dart`

Expected: FAIL because the service file does not exist.

- [ ] **Step 3: Implement minimal service**

Add `FinanceInsightSeverity`, `FinanceInsight`, and `FinanceInsightService.generate`.

- [ ] **Step 4: Run test to verify it passes**

Run: `/usr/bin/env flutter test test/features/coins/domain/services/finance_insight_service_test.dart`

Expected: PASS.

### Task 2: Dashboard Insight Aggregation And UI

**Files:**
- Modify: `app/lib/features/coins/application/providers/dashboard_providers.dart`
- Modify: `app/lib/features/coins/presentation/screens/coins_dashboard_screen.dart`
- Modify: `app/test/features/coins/presentation/screens/coins_dashboard_screen_test.dart`

- [ ] **Step 1: Write failing widget test**

Extend the dashboard test to expect "Coins insights" and an insight title when dashboard data includes transactions or budget risk.

- [ ] **Step 2: Run test to verify it fails**

Run: `/usr/bin/env flutter test test/features/coins/presentation/screens/coins_dashboard_screen_test.dart`

Expected: FAIL because the UI does not render insights yet.

- [ ] **Step 3: Add aggregation and UI**

Add `financeInsights` to `DashboardData`, compute it in `dashboardDataProvider`, and render `_FinanceInsightsSection` after budget overview.

- [ ] **Step 4: Run test to verify it passes**

Run: `/usr/bin/env flutter test test/features/coins/presentation/screens/coins_dashboard_screen_test.dart`

Expected: PASS.

### Task 3: `@Coins` Agent Intent And Tool

**Files:**
- Modify: `app/lib/features/agent_chat/domain/services/intent_parser.dart`
- Modify: `app/lib/features/agent_chat/domain/services/tool_registry.dart`
- Create: `app/test/features/agent_chat/domain/services/intent_parser_test.dart`
- Create: `app/test/features/agent_chat/domain/services/tool_registry_test.dart`

- [ ] **Step 1: Write failing tests**

Test that `@Coins can I save more this month?` parses as `coinsQuestion`, and that executing it returns a message that opens Coins, describes read-only finance help, and includes a professional-advice disclaimer.

- [ ] **Step 2: Run tests to verify they fail**

Run: `/usr/bin/env flutter test test/features/agent_chat/domain/services/intent_parser_test.dart test/features/agent_chat/domain/services/tool_registry_test.dart`

Expected: FAIL because `coinsQuestion` and `CoinsAgentTool` do not exist.

- [ ] **Step 3: Implement parser and tool**

Add `IntentType.coinsQuestion`, phrase detection for `@coins`, "can I save", "spending insight", "subscription review", and a `CoinsAgentTool` that handles the intent.

- [ ] **Step 4: Run tests to verify they pass**

Run: `/usr/bin/env flutter test test/features/agent_chat/domain/services/intent_parser_test.dart test/features/agent_chat/domain/services/tool_registry_test.dart`

Expected: PASS.

### Task 4: Final Verification

**Files:**
- All touched Dart files.

- [ ] **Step 1: Format changed Dart files**

Run: `/usr/bin/env dart format app/lib/features/coins/domain/services/finance_insight_service.dart app/test/features/coins/domain/services/finance_insight_service_test.dart app/lib/features/coins/application/providers/dashboard_providers.dart app/lib/features/coins/presentation/screens/coins_dashboard_screen.dart app/test/features/coins/presentation/screens/coins_dashboard_screen_test.dart app/lib/features/agent_chat/domain/services/intent_parser.dart app/lib/features/agent_chat/domain/services/tool_registry.dart app/test/features/agent_chat/domain/services/intent_parser_test.dart app/test/features/agent_chat/domain/services/tool_registry_test.dart`

- [ ] **Step 2: Run focused verification**

Run: `/usr/bin/env flutter test test/features/coins/domain/services/finance_insight_service_test.dart test/features/coins/presentation/screens/coins_dashboard_screen_test.dart test/features/agent_chat/domain/services/intent_parser_test.dart test/features/agent_chat/domain/services/tool_registry_test.dart`

Expected: PASS.

