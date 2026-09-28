import 'dart:io';

import 'package:airo_license/airo_license.dart';
import 'package:flutter_test/flutter_test.dart';

LicenseService _service({
  LicenseSecureStorage? storage,
  LicenseClient? client,
}) {
  final secure = storage ?? MemoryLicenseSecureStorage();
  return LicenseService(
    identity: InstallationIdentity(storage: secure),
    client: client ?? LocalLicenseClient(),
    cache: MemoryLicenseCache(),
  );
}

void main() {
  test('initialize is local-first free with no capabilities', () async {
    final service = _service();
    final snapshot = await service.initialize();

    expect(snapshot.isLocalOnly, isTrue);
    expect(snapshot.licenseType, LicenseType.free);
    expect(snapshot.entitlement, LicenseEntitlement.free);
    expect(snapshot.status, LicenseLifecycleStatus.active);
    expect(snapshot.devicePolicy.isUnlimited, isTrue);
    expect(snapshot.signature, isNull);
    expect(
      service.hasCapability(AikaLicenseCapabilities.epgReminders),
      isFalse,
    );
    expect(service.purchases, isA<UnavailablePurchaseProvider>());
  });

  test('repeated initialize reuses installation and license ids', () async {
    final storage = MemoryLicenseSecureStorage();
    final client = LocalLicenseClient();
    final first = _service(storage: storage, client: client);
    final firstSnap = await first.initialize();

    final second = _service(storage: storage, client: client);
    final secondSnap = await second.initialize();

    expect(secondSnap.installationId, firstSnap.installationId);
    expect(secondSnap.licenseId, firstSnap.licenseId);
  });

  test(
    'UnavailablePurchaseProvider never reports store entitlements',
    () async {
      const purchases = UnavailablePurchaseProvider();
      await purchases.initialize();
      expect(await purchases.getEntitlements(), isEmpty);
      expect((await purchases.restorePurchases()).entitlementIds, isEmpty);
      expect(purchases.customerChanges, isA<Stream<PurchaseCustomerInfo>>());
    },
  );

  test('pairing and transfer are stubs, not partial implementations', () async {
    final service = _service();
    await service.initialize();

    expect(service.pairDevice(), throwsA(isA<LicenseException>()));
    expect(service.transferLicense(), throwsA(isA<LicenseException>()));
  });

  test(
    'package pubspec and sources do not depend on purchases or backends',
    () {
      final root = Directory.current.path.contains('packages/airo_license')
          ? Directory.current
          : Directory('packages/airo_license');
      final pubspec = File('${root.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('purchases_flutter')));
      expect(pubspec, isNot(contains('purchases_dart')));
      expect(pubspec, isNot(contains('revenuecat')));
      expect(pubspec, isNot(contains('supabase')));
      expect(pubspec, isNot(contains('core_auth')));
      expect(pubspec, isNot(contains('http:')));
      expect(pubspec, isNot(contains('dio:')));

      final dartFiles = Directory('${root.path}/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('package:http/')));
        expect(source, isNot(contains('package:dio/')));
        expect(source, isNot(contains('package:supabase')));
        expect(source, isNot(contains('package:purchases')));
        expect(source, isNot(contains('package:core_auth')));
        expect(source, isNot(contains('HttpClient')));
      }
    },
  );

  test('v1 capability keys match core_entitlements ProFeature stable ids', () {
    expect(AikaLicenseCapabilities.all, {
      'import_intelligence',
      'regional_ranking',
      'epg_reminders',
      'metadata_enrichment',
      'sports_desk',
      'multi_source_failover',
      'coin_encrypted_backup_restore',
      'source_connection_diagnostics',
      'mind_indic_intelligence',
    });
  });
}
