import 'package:airo_app/core/app/airo_app.dart';
import 'package:feature_iptv/feature_iptv.dart' show sharedPreferencesProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Returns the first [Finder] that locates at least one widget, or falls
/// back to the last entry so that the Patrol tap surfaces a clear error.
Finder _firstAvailable(List<Finder> finders) {
  for (final f in finders) {
    if (f.evaluate().isNotEmpty) return f;
  }
  return finders.last;
}

const _selectedAssistantModelKey = 'selected_assistant_model_id';
const _isLoggedInKey = 'is_logged_in';
const _currentUserKey = 'current_user';
const _journeyUserJson =
    '{"id":"coins-journey-user","username":"Coins Journey Tester","isAdmin":true,"isGoogleUser":false,"createdAt":"2026-06-22T00:00:00.000Z"}';

void main() {
  patrolTest('Coins & Assistant - E2E User Journeys', ($) async {
    // 1. Mock Login State & Assistant Model in SharedPreferences
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      _selectedAssistantModelKey: 'gemini-nano',
      _isLoggedInKey: true,
      _currentUserKey: _journeyUserJson,
    });
    final prefs = await SharedPreferences.getInstance();

    // 2. Launch Application — use ProviderScope + AiroApp directly
    //    instead of app.main() to avoid GlobalErrorHandler overriding
    //    FlutterError.onError (which conflicts with the test framework).
    await $.pumpWidgetAndSettle(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const AiroApp(),
      ),
    );

    // Wait for the main shell navigation to load
    await $.waitUntilVisible(
      find.text('Coins'),
      timeout: const Duration(seconds: 45),
    );

    // 3. Navigate to Coins Tab
    final coinsTab = find.byKey(const ValueKey('app_nav_coins'));
    expect(coinsTab, findsOneWidget);
    await $(coinsTab).tap();
    await $.pumpAndSettle();

    // 4. Add Income
    final addTransactionButton = find.text('Add Expense');
    await $(addTransactionButton).tap();
    await $.pumpAndSettle();

    // Toggle to 'Income'
    await $('Income').tap();
    await $.pumpAndSettle();

    // Enter Amount
    final amountField = find.byKey(const ValueKey('add_expense_amount_field'));
    await $(amountField).enterText('50000.00');
    await $.pumpAndSettle();

    // Enter Description
    final descField = find.byKey(
      const ValueKey('add_expense_description_field'),
    );
    await $(descField).enterText('Monthly Salary');
    await $.pumpAndSettle();

    // Dismiss keyboard
    FocusManager.instance.primaryFocus?.unfocus();
    await $.pumpAndSettle();

    // Choose Category: 'Salary' (ChoiceChip)
    await $('Salary').tap();
    await $.pumpAndSettle();

    // Choose Account: 'Cash'
    await $('Cash').tap();
    await $.pumpAndSettle();

    // Save transaction
    await $('Save').tap();
    await $.pumpAndSettle();

    // Check for validation/database errors displayed in SnackBar
    final errorFinder = find.textContaining('Error:');
    if (errorFinder.evaluate().isNotEmpty) {
      final Text errorTextWidget = $.tester.widget(errorFinder);
      throw Exception('Save failed with error: ${errorTextWidget.data}');
    }

    // Wait for dashboard to reload
    await $.waitUntilExists($('Budgets'), timeout: const Duration(seconds: 20));

    // 5. Navigate to Budgets Screen
    final inkWellFinder = find.ancestor(
      of: find.text('Budgets'),
      matching: find.byType(InkWell),
    );
    final inkWell = $.tester.widget<InkWell>(inkWellFinder);
    inkWell.onTap!();
    await $.pumpAndSettle();

    // Verify on Budgets Screen
    expect($('Budgets'), findsWidgets);

    // Click 'Add Budget' or 'Create Your First Budget'
    final addBudgetButton = _firstAvailable([
      find.byKey(const ValueKey('add_budget_fab_button')),
      find.text('Add Budget'),
      find.text('Create Your First Budget'),
    ]);
    await $(addBudgetButton).tap();
    await $.pumpAndSettle();

    // Enter Budget details:
    // Limit
    final budgetLimitField = find.byKey(
      const ValueKey('add_budget_limit_field'),
    );
    await $(budgetLimitField).enterText('10000.00');
    await $.pumpAndSettle();

    // Name
    final budgetNameField = find.byKey(const ValueKey('add_budget_name_field'));
    await $(budgetNameField).enterText('Food and Drink');
    await $.pumpAndSettle();

    // Dismiss keyboard
    FocusManager.instance.primaryFocus?.unfocus();
    await $.pumpAndSettle();

    // Category ChoiceChip
    final foodCategoryChip = find.byKey(
      const ValueKey('add_budget_category_food'),
    );
    await $(foodCategoryChip).tap();
    await $.pumpAndSettle();

    // Save Budget
    final saveBudgetButton = find.byKey(
      const ValueKey('add_budget_save_button'),
    );
    await $(saveBudgetButton).tap();
    await $.pumpAndSettle();

    // Verify budget is added (Food category budget card is shown)
    expect($('food'), findsOneWidget);
    expect($('Monthly'), findsOneWidget);

    // Go back to Coins Dashboard
    await $(find.byIcon(Icons.arrow_back)).tap();
    await $.pumpAndSettle();

    // 6. Create Group and Add Members
    final splitInkWellFinder = find.ancestor(
      of: find.text('Split New Expense').first,
      matching: find.byType(InkWell),
    );
    final splitInkWell = $.tester.widget<InkWell>(splitInkWellFinder);
    splitInkWell.onTap!();
    await $.pumpAndSettle();

    // Tap 'New Group' FAB
    final newGroupButton = find.text('New Group');
    await $(newGroupButton).tap();
    await $.pumpAndSettle();

    // Fill Group Name
    final groupNameField = find.byKey(
      const ValueKey('create_group_name_field'),
    );
    await $(groupNameField).enterText('Goa Trip');
    await $.pumpAndSettle();

    // Fill Group Description
    final groupDescField = find.byKey(
      const ValueKey('create_group_desc_field'),
    );
    await $(groupDescField).enterText('E2E Test Goa trip sharing');
    await $.pumpAndSettle();

    // Dismiss keyboard
    FocusManager.instance.primaryFocus?.unfocus();
    await $.pumpAndSettle();

    // Click 'Create' button
    await $('Create').tap();
    await $.pumpAndSettle();

    // Verify Group details screen
    expect($('Goa Trip'), findsWidgets);

    // Add Member: 'Rahul'
    final addMemberIcon = find.byIcon(Icons.person_add_outlined);
    await $(addMemberIcon).tap();
    await $.pumpAndSettle();

    final memberNameField = find.byKey(const ValueKey('add_member_name_field'));
    await $(memberNameField).enterText('Rahul');
    await $.pumpAndSettle();

    // Dismiss keyboard
    FocusManager.instance.primaryFocus?.unfocus();
    await $.pumpAndSettle();

    await $('Add').tap();
    await $.pumpAndSettle();

    // Navigate to members tab to verify member is added
    await $('Members').tap();
    await $.pumpAndSettle();
    expect($('Rahul'), findsOneWidget);

    // 7. Share Expense / Split Expense inside the Group
    // Navigate back to Expenses tab
    await $('Expenses').tap();
    await $.pumpAndSettle();

    // Tap Add Expense inside group
    final addGroupExpenseButton = find.text('Add Expense');
    await $(addGroupExpenseButton).tap();
    await $.pumpAndSettle();

    // Select 'Add manually' from bottom sheet
    await $('Add manually').tap();
    await $.pumpAndSettle();

    // Enter manual split amount
    final splitAmountField = find.byKey(
      const ValueKey('add_split_amount_field'),
    );
    await $(splitAmountField).enterText('1200.00');
    await $.pumpAndSettle();

    // Enter split description
    final splitDescField = find.byKey(const ValueKey('add_split_desc_field'));
    await $(splitDescField).enterText('Dinner at Goa');
    await $.pumpAndSettle();

    // Dismiss keyboard
    FocusManager.instance.primaryFocus?.unfocus();
    await $.pumpAndSettle();

    // Tap Paid by 'You'
    await $('You').tap();
    await $.pumpAndSettle();

    // Select split check box for 'Rahul'
    await $('Rahul').tap();
    await $.pumpAndSettle();

    // Save split expense
    await $('Save').tap();
    await $.pumpAndSettle();

    // Verify Goa Dinner is in list
    expect($('Dinner at Goa'), findsOneWidget);

    // Go back to Coins Dashboard
    await $(find.byIcon(Icons.arrow_back)).tap();
    await $.pumpAndSettle();
    await $(find.byIcon(Icons.arrow_back)).tap();
    await $.pumpAndSettle();

    // Check for dashboard loading errors
    final dashboardErrorFinder = find.textContaining('Error:');
    if (dashboardErrorFinder.evaluate().isNotEmpty) {
      final Text errorTextWidget = $.tester.widget(dashboardErrorFinder);
      throw Exception(
        'Dashboard loading failed with error: ${errorTextWidget.data}',
      );
    }

    // Wait for dashboard to finish loading
    await $.waitUntilExists(
      $('Add Expense'),
      timeout: const Duration(seconds: 20),
    );

    // 8. Add Personal Expense and Verify Budget Reacts
    await $(addTransactionButton).tap();
    await $.pumpAndSettle();

    // Make sure Expense is toggled (default is Expense)
    await $('Expense').tap();
    await $.pumpAndSettle();

    // Enter Amount: 3000.00
    await $(amountField).enterText('3000.00');
    await $.pumpAndSettle();

    // Enter Description: Dinner Party
    await $(descField).enterText('Dinner Party');
    await $.pumpAndSettle();

    // Dismiss keyboard
    FocusManager.instance.primaryFocus?.unfocus();
    await $.pumpAndSettle();

    // Choose Category: Food
    await $('Food').tap();
    await $.pumpAndSettle();

    // Choose Account: Cash
    await $('Cash').tap();
    await $.pumpAndSettle();

    // Save
    await $('Save').tap();
    await $.pumpAndSettle();

    // Navigate to Budgets Screen
    final secondBudgetsInkWellFinder = find.ancestor(
      of: find.text('Budgets'),
      matching: find.byType(InkWell),
    );
    final secondBudgetsInkWell = $.tester.widget<InkWell>(
      secondBudgetsInkWellFinder,
    );
    secondBudgetsInkWell.onTap!();
    await $.pumpAndSettle();

    // Verify budget status reflects spending (3,000.00 is spent)
    expect(find.textContaining('3,000'), findsWidgets);

    // Go back to Coins Dashboard
    await $(find.byIcon(Icons.arrow_back)).tap();
    await $.pumpAndSettle();

    // 9. Navigate to Mind (Assistant) Tab
    final assistantTab = find.byKey(const ValueKey('app_nav_mind'));
    expect(assistantTab, findsOneWidget);
    await $(assistantTab).tap();
    await $.pumpAndSettle();

    // Send a message asking "Check my schedule for today"
    final chatInput = find.byKey(const ValueKey('agent_chat_input'));
    await $(chatInput).enterText('Check my schedule for today');
    await $.pumpAndSettle();

    final sendButton = find.byKey(const ValueKey('agent_chat_send_button'));
    await $(sendButton).tap();
    await $.pumpAndSettle();

    // Wait for the response
    await $.pump(const Duration(seconds: 5));
    // Verify chatbot elements
    expect($('Performed action'), findsWidgets);
  });
}
