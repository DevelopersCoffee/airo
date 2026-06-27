import '../../domain/entities/budget.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/models/budget_status.dart';

/// Notification service for Coins feature
///
/// Handles budget alerts, settlement reminders, and other notifications.
///
/// Phase: 1 & 2
/// See: docs/features/coins/PROJECT_STRUCTURE.md
abstract class CoinsNotificationService {
  /// Schedule a budget alert notification
  Future<void> scheduleBudgetAlert({
    required Budget budget,
    required BudgetStatus status,
  });

  /// Cancel a scheduled budget alert
  Future<void> cancelBudgetAlert(String budgetId);

  /// Send settlement request notification
  Future<void> sendSettlementRequest({
    required Settlement settlement,
    required String toUserName,
  });

  /// Send settlement received notification
  Future<void> sendSettlementReceived({
    required Settlement settlement,
    required String fromUserName,
  });

  /// Send group invite notification
  Future<void> sendGroupInvite({
    required String groupId,
    required String groupName,
    required String inviterName,
    required String inviteCode,
  });

  /// Send daily spending summary
  Future<void> sendDailySummary({
    required int spentTodayCents,
    required int safeToSpendCents,
    required String currencyCode,
  });

  /// Clear all notifications
  Future<void> clearAll();
}

/// Default implementation using local notifications
class CoinsNotificationServiceImpl implements CoinsNotificationService {
  // TODO: Inject FlutterLocalNotificationsPlugin or similar

  @override
  Future<void> scheduleBudgetAlert({
    required Budget budget,
    required BudgetStatus status,
  }) async {
    // TODO: Implement using flutter_local_notifications
    // Schedule notification when budget reaches alert threshold
    // Example: "⚠️ You've used 80% of your Food budget (₹8,000 of ₹10,000)"
  }

  @override
  Future<void> cancelBudgetAlert(String budgetId) async {
    // TODO: Cancel scheduled notification by ID
  }

  @override
  Future<void> sendSettlementRequest({
    required Settlement settlement,
    required String toUserName,
  }) async {
    // TODO: Send push notification
    // Example: "💰 Settlement request: Pay ₹500 to Rahul"
  }

  @override
  Future<void> sendSettlementReceived({
    required Settlement settlement,
    required String fromUserName,
  }) async {
    // TODO: Send push notification
    // Example: "✅ Rahul paid you ₹500"
  }

  @override
  Future<void> sendGroupInvite({
    required String groupId,
    required String groupName,
    required String inviterName,
    required String inviteCode,
  }) async {
    // TODO: Send push notification
    // Example: "👥 Priya invited you to join 'Goa Trip'"
  }

  @override
  Future<void> sendDailySummary({
    required int spentTodayCents,
    required int safeToSpendCents,
    required String currencyCode,
  }) async {
    // TODO: Schedule daily notification at configured time
    // Example: "📊 Today: Spent ₹1,200 | Safe to spend: ₹800"
  }

  @override
  Future<void> clearAll() async {
    // TODO: Clear all pending and displayed notifications
  }
}
