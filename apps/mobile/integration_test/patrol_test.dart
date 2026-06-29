import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:airo_app/main.dart' as app;
import 'package:airo_app/features/bill_split/presentation/screens/bill_split_screen.dart';
import 'package:airo_app/features/bill_split/presentation/screens/itemized_split_screen.dart';

/// Patrol E2E tests for Airo app - iOS/Android device testing
///
/// Run with:
///   patrol test -t integration_test/patrol_test.dart
///
/// For Android:
///   patrol test -t integration_test/patrol_test.dart --target android
///
/// For iOS:
///   patrol test -t integration_test/patrol_test.dart --target ios
///
/// Testing Strategy:
/// 1. Playwright tests (browser) → 2. Patrol tests (device) → 3. Deploy

void main() {
  patrolTest('Bill Split - Complete flow on device', ($) async {
    // Launch the app
    app.main();
    await $.pumpAndSettle();

    // Navigate to Coins tab
    await $(#coins_tab).tap();
    await $.pumpAndSettle();

    // Tap on Split Bill
    await $('Split Bill').tap();
    await $.pumpAndSettle();

    // Verify Bill Split screen is shown
    expect($(BillSplitTestIds.screen), findsOneWidget);
    expect($('Add expense'), findsOneWidget);
  });

  patrolTest('Bill Split - Add participant and enter amount', ($) async {
    app.main();
    await $.pumpAndSettle();

    await $(#coins_tab).tap();
    await $.pumpAndSettle();

    await $('Split Bill').tap();
    await $.pumpAndSettle();

    // Enter description
    await $(BillSplitTestIds.descriptionInput).enterText('Lunch');
    await $.pumpAndSettle();

    // Enter amount
    await $(BillSplitTestIds.amountInput).enterText('250');
    await $.pumpAndSettle();

    // Open participant picker
    await $(BillSplitTestIds.participantsSection).tap();
    await $.pumpAndSettle();

    // Close picker
    await $('Done').tap();
    await $.pumpAndSettle();
  });

  patrolTest('Itemized Split - Open and verify UI', ($) async {
    app.main();
    await $.pumpAndSettle();

    await $(#coins_tab).tap();
    await $.pumpAndSettle();

    await $('Split Bill').tap();
    await $.pumpAndSettle();

    // Add participant first
    await $(BillSplitTestIds.participantsSection).tap();
    await $.pumpAndSettle();
    await $('Done').tap();
    await $.pumpAndSettle();

    // Navigate to itemized split
    await $(BillSplitTestIds.splitByItemsButton).tap();
    await $.pumpAndSettle();

    // Verify itemized split screen
    expect($(ItemizedSplitTestIds.screen), findsOneWidget);
    expect($('Upload Receipt'), findsOneWidget);
  });

  patrolTest('Itemized Split - Camera permission and photo capture', ($) async {
    app.main();
    await $.pumpAndSettle();

    await $(#coins_tab).tap();
    await $.pumpAndSettle();

    await $('Split Bill').tap();
    await $.pumpAndSettle();

    // Add participant
    await $(BillSplitTestIds.participantsSection).tap();
    await $.pumpAndSettle();
    await $('Done').tap();
    await $.pumpAndSettle();

    // Navigate to itemized split
    await $(BillSplitTestIds.splitByItemsButton).tap();
    await $.pumpAndSettle();

    // Tap camera button (will request permission on device)
    await $(ItemizedSplitTestIds.cameraButton).tap();

    // Handle native camera permission dialog
    // Using platformAutomator.mobile (Patrol 4.x API, replaces deprecated .native)
    if (await $.platformAutomator.mobile.isPermissionDialogVisible()) {
      await $.platformAutomator.mobile.grantPermissionWhenInUse();
    }

    // Note: Actual photo capture would happen here on real device
    // For CI, we might mock the image picker
  });

  patrolTest('Itemized Split - Gallery selection', ($) async {
    app.main();
    await $.pumpAndSettle();

    await $(#coins_tab).tap();
    await $.pumpAndSettle();

    await $('Split Bill').tap();
    await $.pumpAndSettle();

    // Add participant
    await $(BillSplitTestIds.participantsSection).tap();
    await $.pumpAndSettle();
    await $('Done').tap();
    await $.pumpAndSettle();

    // Navigate to itemized split
    await $(BillSplitTestIds.splitByItemsButton).tap();
    await $.pumpAndSettle();

    // Tap gallery button
    await $(ItemizedSplitTestIds.galleryButton).tap();

    // Handle native photo picker
    // Using platformAutomator.mobile (Patrol 4.x API, replaces deprecated .native)
    if (await $.platformAutomator.mobile.isPermissionDialogVisible()) {
      await $.platformAutomator.mobile.grantPermissionWhenInUse();
    }
  });
}
