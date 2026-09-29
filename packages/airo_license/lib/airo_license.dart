/// Accountless, local-first licensing contracts for Airo products.
///
/// This package must stay free of RevenueCat, Supabase, HTTP clients, and
/// `core_auth`. Hosted registration and purchases belong in `airo-pro`.
library;

export 'src/api/license_client.dart';
export 'src/core/capability.dart';
export 'src/core/license.dart';
export 'src/core/license_snapshot_codec.dart';
export 'src/core/license_snapshot_verifier.dart';
export 'src/exceptions/license_exception.dart';
export 'src/identity/installation_identity.dart';
export 'src/providers/purchase_provider.dart';
export 'src/services/license_service.dart';
export 'src/storage/license_cache.dart';
export 'src/storage/secure_storage.dart';
