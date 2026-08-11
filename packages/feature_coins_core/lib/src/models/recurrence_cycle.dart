/// Billing cadence a [DetectedSubscription] was inferred to follow.
///
/// Distinct from `Subscription.BillingCycle` (a user-confirmed record) — this
/// is the detector's own vocabulary for a candidate it inferred from raw
/// transaction gaps, before anyone has confirmed it as a real subscription.
enum RecurrenceCycle {
  weekly('Weekly'),
  monthly('Monthly'),
  quarterly('Quarterly'),
  yearly('Yearly');

  final String displayName;
  const RecurrenceCycle(this.displayName);
}
