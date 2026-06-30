# API Baseline (PFR-1)

> This document is a snapshot of the public API surface for Program 0 platform packages.

## platform_core

### Classes & Interfaces
- `BootstrapCompletedEvent`
- `BootstrapContext`
- `BootstrapCoordinator`
- `BootstrapEvent`
- `BootstrapMetrics`
- `BootstrapRegistry`
- `BootstrapReport`
- `BootstrapStartedEvent`
- `BootstrapTask`
- `BootstrapTaskCompletedEvent`
- `BootstrapTaskFailedEvent`
- `BootstrapTaskStartedEvent`
- `BootstrapValidator`
- `ConfigurationException`
- `DependencyException`
- `DependencyResolver`
- `Disposable`
- `ErrorEvent`
- `FatalFailure`
- `FeatureModule`
- `HealthCheck`
- `Initializable`
- `InitializationException`
- `LifecycleAware`
- `LifecycleEvent`
- `LifecycleException`
- `PlatformCapability`
- `PlatformCapabilityRegistry`
- `PlatformEnvironment`
- `PlatformEvent`
- `PlatformException`
- `PlatformReadyEvent`
- `PlatformRepository`
- `PlatformService`
- `PlatformTransaction`
- `PlatformVersion`
- `RecoverableFailure`
- `Result`
- `SemanticVersion`
- `Success`

### Enums
- `LifecycleState`

## platform_events

### Classes & Interfaces
- `DefaultEventBus`
- `EventBus`
- `EventBusDiagnostics`
- `EventFilter`
- `EventInterceptor`
- `EventMetadata`
- `EventPublisher`
- `EventSubscriber`
- `PlatformEvent`

### Enums
- `EventCategory`

### Typedefs
- `EventHandler`

## platform_logging

### Classes & Interfaces
- `CategoryFilter`
- `ConsoleSink`
- `DefaultLogContextProvider`
- `DiagnosticCollector`
- `DiagnosticReport`
- `DiagnosticSnapshot`
- `HumanReadableFormatter`
- `JsonFormatter`
- `LevelFilter`
- `LogContext`
- `LogContextProvider`
- `LogEntry`
- `LogFilter`
- `LogFormatter`
- `LogMetadata`
- `LogSink`
- `Logger`
- `LoggingBootstrapTask`
- `MemorySink`
- `PerformanceMarker`
- `PlatformLogger`

### Enums
- `HealthStatus`
- `LogCategory`
- `LogLevel`

## platform_settings

### Classes & Interfaces
- `DefaultSettingsRegistry`
- `EventBusSettingsObserver`
- `MemorySettingsService`
- `SettingDefinition`
- `SettingMetadata`
- `SettingsChangedEvent`
- `SettingsMigration`
- `SettingsObserver`
- `SettingsRegistry`
- `SettingsService`
- `SettingsValidator`
- `ThemeSetting`

### Enums
- `SettingFlag`
- `SettingType`
- `SettingsNamespace`

## platform_storage

### Classes & Interfaces
- `AppDatabase`
- `AuditMetadata`
- `DatabaseBackupProvider`
- `DatabaseDiagnostics`
- `DatabaseHealthChecker`
- `DatabaseMigration`
- `DefaultRepositoryFactory`
- `DriftStorageService`
- `DriftTransactionManager`
- `DurationConverter`
- `JsonMapConverter`
- `RepositoryFactory`
- `SoftDelete`
- `StorageBootstrapTask`
- `StorageService`
- `TransactionManager`
- `UriConverter`
- `WorkspaceIsolation`

## platform_filesystem

### Classes & Interfaces
- `AudioFile`
- `CacheClearedEvent`
- `CacheManager`
- `CryptoIntegrityVerifier`
- `DefaultDirectoryProvider`
- `DefaultFileManager`
- `DefaultFilesystemService`
- `DirectoryCreatedEvent`
- `DirectoryProvider`
- `DocumentFile`
- `ExportFile`
- `FileDeletedEvent`
- `FileManager`
- `FilesystemBootstrapTask`
- `FilesystemService`
- `ImageFile`
- `ImportExportService`
- `IntegrityResult`
- `IntegrityVerifier`
- `ModelFile`
- `PlatformFile`
- `TemporaryFile`
- `WorkspaceFile`

## platform_jobs

### Classes & Interfaces
- `DefaultCancellationToken`
- `DefaultCancellationTokenSource`
- `DefaultJobScheduler`
- `Job`
- `JobCancellationToken`
- `JobCancellationTokenSource`
- `JobCancelledEvent`
- `JobExecutor`
- `JobFailedEvent`
- `JobMonitor`
- `JobProgressEvent`
- `JobQueue`
- `JobQueuedEvent`
- `JobRetriedEvent`
- `JobScheduler`
- `JobStartedEvent`
- `JobSucceededEvent`
- `JobWorker`
- `JobsBootstrapTask`
- `RetryPolicy`

### Enums
- `JobPriority`
- `JobQueueType`
- `JobStatus`
- `RetryStrategy`

## design_system

### Classes & Interfaces
- `AiroThemeTokens`
- `AppButton`
- `AppCard`
- `AppColors`
- `AppSpacing`
- `AppTheme`
- `AppThemeDefinition`
- `AppTypography`
- `BedtimeTheme`
- `EmptyStateWidget`
- `ErrorCard`
- `ErrorDisplayWidget`
- `ErrorView`
- `InlineError`
- `LoadingButton`
- `LoadingIndicator`
- `LoadingOverlay`
- `LoadingWidget`
- `NetworkErrorWidget`

### Enums
- `AppButtonSize`
- `AppButtonVariant`
- `AppThemeId`
- `LoadingIndicatorSize`

