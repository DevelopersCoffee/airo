# Public API Inventory (Program 0 Baseline)

This document captures the approved public API exports for the foundation platform packages.
Any additions to these exports should be reviewed for implementation leaks.

## platform_core
* `src/bootstrap/bootstrap_context.dart`
* `src/bootstrap/bootstrap_coordinator.dart`
* `src/bootstrap/bootstrap_phase.dart`
* `src/bootstrap/bootstrap_result.dart`
* `src/contracts/bootstrap_task.dart`
* `src/contracts/disposable.dart`
* `src/contracts/feature_module.dart`
* `src/contracts/health_check.dart`
* `src/contracts/initializable.dart`
* `src/contracts/lifecycle_aware.dart`
* `src/contracts/platform_capability.dart`
* `src/contracts/platform_service.dart`
* `src/contracts/platform_repository.dart`
* `src/environment/platform_environment.dart`
* `src/events/platform_event.dart`
* `src/exceptions/platform_exceptions.dart`
* `src/lifecycle/lifecycle_state.dart`
* `src/providers/platform_providers.dart`
* `src/result/result.dart`
* `src/version/platform_version.dart`

## platform_logging
* `src/bootstrap/logging_bootstrap_task.dart`
* `src/context/log_context.dart`
* `src/context/log_context_provider_interface.dart`
* `src/context/log_metadata.dart`
* `src/contracts/log_filter.dart`
* `src/contracts/log_formatter.dart`
* `src/contracts/log_sink.dart`
* `src/contracts/logger.dart`
* `src/diagnostics/diagnostic_contracts.dart`
* `src/events/log_entry.dart`
* `src/filters/category_filter.dart`
* `src/filters/level_filter.dart`
* `src/formatter/human_readable_formatter.dart`
* `src/formatter/json_formatter.dart`
* `src/levels/log_category.dart`
* `src/levels/log_level.dart`
* `src/logger/platform_logger.dart`
* `src/providers/logging_providers.dart`
* `src/sinks/console_sink.dart`
* `src/sinks/memory_sink.dart`

## platform_events
* `src/contracts/platform_event.dart`
* `src/contracts/event_bus.dart`
* `src/contracts/event_publisher.dart`
* `src/contracts/event_subscriber.dart`
* `src/contracts/event_filter.dart`
* `src/contracts/event_interceptor.dart`
* `src/event_types/event_category.dart`
* `src/event_types/event_metadata.dart`
* `src/diagnostics/event_diagnostics.dart`
* `src/providers/event_providers.dart`

## platform_settings
* `src/models/settings_namespace.dart`
* `src/models/setting_type.dart`
* `src/models/setting_flag.dart`
* `src/models/setting_metadata.dart`
* `src/contracts/setting_definition.dart`
* `src/contracts/settings_registry.dart`
* `src/contracts/settings_service.dart`
* `src/contracts/settings_validator.dart`
* `src/contracts/settings_migration.dart`
* `src/contracts/settings_observer.dart`
* `src/observers/settings_changed_event.dart`
* `src/observers/event_bus_settings_observer.dart`
* `src/providers/settings_providers.dart`
* `src/defaults/theme_setting.dart`

## platform_storage
* `src/contracts/storage_service.dart`
* `src/contracts/repository_factory.dart`
* `src/contracts/transaction_manager.dart`
* `src/contracts/database_migration.dart`
* `src/contracts/database_health_checker.dart`
* `src/contracts/database_backup_provider.dart`
* `src/entities/audit_metadata.dart`
* `src/converters/central_converters.dart`
* `src/providers/storage_providers.dart`
* `src/bootstrap/storage_bootstrap_task.dart`

## platform_filesystem
* `src/contracts/filesystem_service.dart`
* `src/contracts/directory_provider.dart`
* `src/contracts/file_manager.dart`
* `src/contracts/cache_manager.dart`
* `src/contracts/integrity_verifier.dart`
* `src/contracts/import_export_service.dart`
* `src/files/platform_file.dart`
* `src/files/file_types.dart`
* `src/events/filesystem_events.dart`
* `src/providers/filesystem_providers.dart`
* `src/bootstrap/filesystem_bootstrap_task.dart`

## design_system
(Not actively exporting platform logic - assumed UI-only)
