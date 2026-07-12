// Core data layer for Airo.
//
// Contains API clients, database access, and repository implementations.
// HTTP Client
export 'src/http/api_client.dart';
export 'src/http/api_exception.dart';
export 'src/http/certificate_pinner.dart';

// Local Storage
export 'src/storage/key_value_store.dart';
export 'src/storage/preferences_store.dart';
export 'src/storage/secure_store.dart';
export 'src/storage/flutter_secure_store.dart';
export 'src/storage/life_track_local_data_source.dart';
export 'src/storage/templates/life_track_template_fallback_resolver.dart';
export 'src/storage/templates/template_registry.dart';

// Connectivity
export 'src/connectivity/connectivity_service.dart';

// Encryption
export 'src/encryption/encryption_service.dart';

// Sync & Offline
export 'src/sync/sync_operation.dart';
export 'src/sync/sync_status.dart';
export 'src/sync/sync_service.dart';
export 'src/sync/outbox_repository.dart';

// Base Repository
export 'src/repositories/base_repository.dart';
export 'src/repositories/life_track_repository_impl.dart';

// Plugin Storage and Runtime Controls
export 'src/plugins/local_plugin_storage.dart';
export 'src/plugins/plugin_kill_switch_service.dart';

// Bug Reporting
export 'src/bug_report/bug_report_model.dart';
export 'src/bug_report/github_issue_service.dart';
