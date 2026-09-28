import '../api/license_client.dart';
import '../core/license.dart';
import '../exceptions/license_exception.dart';
import '../identity/installation_identity.dart';
import '../providers/purchase_provider.dart';
import '../storage/license_cache.dart';

const kDefaultAikaStreamProductId = 'aika_stream';

/// Local-first license coordinator. Does not call a hosted API.
class LicenseService {
  LicenseService({
    required this.identity,
    required this.client,
    required this.cache,
    PurchaseProvider? purchases,
    this.productId = kDefaultAikaStreamProductId,
    this.keyManager = const _NullKeyManager(),
  }) : purchases = purchases ?? const UnavailablePurchaseProvider();

  final InstallationIdentity identity;
  final LicenseClient client;
  final LicenseCache cache;
  final PurchaseProvider purchases;
  final InstallationKeyManager keyManager;
  final String productId;

  LicenseSnapshot? _current;

  bool get isInitialized => _current != null;

  LicenseSnapshot get status {
    final current = _current;
    if (current == null) {
      throw LicenseException(
        LicenseErrorCode.invalidSnapshot,
        'LicenseService.initialize must run first.',
      );
    }
    return current;
  }

  String get licenseId => status.licenseId;
  String get installationId => status.installationId;
  LicenseType get licenseType => status.licenseType;
  LicenseEntitlement get entitlement => status.entitlement;
  int get maxDevices => status.devicePolicy.maxDevices;

  bool hasCapability(String capabilityId) => status.hasCapability(capabilityId);

  Future<LicenseSnapshot> initialize() async {
    await purchases.initialize();
    final installationId = await identity.getOrCreateId();
    final publicKey = await keyManager.publicKey();
    final snapshot = await client.initialize(
      productId: productId,
      installationId: installationId,
      publicKey: publicKey,
    );
    await cache.write(snapshot);
    _current = snapshot;
    return snapshot;
  }

  /// Phone↔TV pairing is overlay + hosted API. Not in this package.
  Future<Never> pairDevice() async {
    throw LicenseException.stub('pair');
  }

  /// Recovery transfer is a documented stub until a concrete flow exists.
  Future<Never> transferLicense() async {
    throw LicenseException.stub('transfer');
  }
}

class _NullKeyManager implements InstallationKeyManager {
  const _NullKeyManager();

  @override
  Future<String?> publicKey() async => null;

  @override
  Future<String?> sign(String message) async => null;
}
