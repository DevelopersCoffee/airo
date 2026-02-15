import 'package:equatable/equatable.dart';

/// Billing cycle for subscriptions
enum BillingCycle {
  weekly('Weekly'),
  monthly('Monthly'),
  quarterly('Quarterly'),
  yearly('Yearly');

  final String displayName;
  const BillingCycle(this.displayName);
}

/// Subscription entity for recurring expense tracking
///
/// Tracks recurring subscriptions like Netflix, Spotify, etc.
///
/// Phase: 3 (Advanced Features)
/// See: docs/features/coins/DOMAIN_API_CONTRACTS.md
class Subscription extends Equatable {
  final String id;
  final String name;
  final String? description;
  final int amountCents;
  final String currencyCode;
  final BillingCycle billingCycle;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextBillingDate;
  final String categoryId;
  final String accountId;
  final String? iconUrl;
  final String? websiteUrl;
  final bool isActive;
  final bool autoRenew;
  final int? reminderDaysBefore; // Remind X days before renewal
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Subscription({
    required this.id,
    required this.name,
    this.description,
    required this.amountCents,
    this.currencyCode = 'INR',
    required this.billingCycle,
    required this.startDate,
    this.endDate,
    required this.nextBillingDate,
    required this.categoryId,
    required this.accountId,
    this.iconUrl,
    this.websiteUrl,
    this.isActive = true,
    this.autoRenew = true,
    this.reminderDaysBefore = 3,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get amount in major currency unit
  double get amount => amountCents / 100;

  /// Calculate yearly cost
  int get yearlyCostCents {
    switch (billingCycle) {
      case BillingCycle.weekly:
        return amountCents * 52;
      case BillingCycle.monthly:
        return amountCents * 12;
      case BillingCycle.quarterly:
        return amountCents * 4;
      case BillingCycle.yearly:
        return amountCents;
    }
  }

  /// Check if subscription is due soon
  bool isDueSoon(DateTime now, {int daysThreshold = 7}) {
    return nextBillingDate.difference(now).inDays <= daysThreshold;
  }

  /// Create a copy with updated fields
  Subscription copyWith({
    String? id,
    String? name,
    String? description,
    int? amountCents,
    String? currencyCode,
    BillingCycle? billingCycle,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextBillingDate,
    String? categoryId,
    String? accountId,
    String? iconUrl,
    String? websiteUrl,
    bool? isActive,
    bool? autoRenew,
    int? reminderDaysBefore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      amountCents: amountCents ?? this.amountCents,
      currencyCode: currencyCode ?? this.currencyCode,
      billingCycle: billingCycle ?? this.billingCycle,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      iconUrl: iconUrl ?? this.iconUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      isActive: isActive ?? this.isActive,
      autoRenew: autoRenew ?? this.autoRenew,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        amountCents,
        currencyCode,
        billingCycle,
        startDate,
        endDate,
        nextBillingDate,
        categoryId,
        accountId,
        iconUrl,
        websiteUrl,
        isActive,
        autoRenew,
        reminderDaysBefore,
        createdAt,
        updatedAt,
      ];
}

