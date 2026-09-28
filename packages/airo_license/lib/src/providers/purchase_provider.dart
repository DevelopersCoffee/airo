/// Purchase adapter. The OSS package ships only [UnavailablePurchaseProvider].
/// RevenueCat lives in `airo-pro` and must not be imported here.
abstract interface class PurchaseProvider {
  Future<void> initialize();
  Future<PurchaseCustomerInfo> getCustomerInfo();
  Future<Set<String>> getEntitlements();
  Future<PurchaseCustomerInfo> restorePurchases();
  Stream<PurchaseCustomerInfo> get customerChanges;
}

final class PurchaseCustomerInfo {
  const PurchaseCustomerInfo({
    this.appUserId,
    this.entitlementIds = const {},
    this.isAnonymous = true,
  });

  final String? appUserId;
  final Set<String> entitlementIds;
  final bool isAnonymous;
}

/// Default Play / OSS adapter: no store SDK, no network, no entitlements.
class UnavailablePurchaseProvider implements PurchaseProvider {
  const UnavailablePurchaseProvider();

  static const _empty = PurchaseCustomerInfo();

  @override
  Future<void> initialize() async {}

  @override
  Future<PurchaseCustomerInfo> getCustomerInfo() async => _empty;

  @override
  Future<Set<String>> getEntitlements() async => const {};

  @override
  Future<PurchaseCustomerInfo> restorePurchases() async => _empty;

  @override
  Stream<PurchaseCustomerInfo> get customerChanges => const Stream.empty();
}
