/// Core data layer for Airo
///
/// Contains API clients, database access, and repository implementations.
library core_data;

// HTTP Client
export 'src/http/api_client.dart';
export 'src/http/api_exception.dart';
export 'src/http/certificate_pinner.dart';

// Local Storage
export 'src/storage/key_value_store.dart';
export 'src/storage/preferences_store.dart';
export 'src/storage/secure_store.dart';
export 'src/storage/flutter_secure_store.dart';

// Connectivity
export 'src/connectivity/connectivity_service.dart';

// Encryption
export 'src/encryption/encryption_service.dart';

// Base Repository
export 'src/repositories/base_repository.dart';

