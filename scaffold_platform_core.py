import os

def create_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

base = 'packages/platform_core/lib/src'

# Contracts
create_file(f'{base}/contracts/platform_service.dart', '''abstract interface class PlatformService {
  String get serviceName;
}
''')

create_file(f'{base}/contracts/bootstrap_task.dart', '''import '../bootstrap/bootstrap_context.dart';
import '../bootstrap/bootstrap_phase.dart';
import '../bootstrap/bootstrap_result.dart';

abstract interface class BootstrapTask {
  String get name;
  BootstrapPhase get phase;
  Future<BootstrapResult> execute(BootstrapContext context);
}
''')

create_file(f'{base}/contracts/lifecycle_aware.dart', '''import '../lifecycle/lifecycle_state.dart';

abstract interface class LifecycleAware {
  Future<void> onLifecycleStateChanged(LifecycleState state);
}
''')

create_file(f'{base}/contracts/initializable.dart', '''abstract interface class Initializable {
  Future<void> initialize();
}
''')

create_file(f'{base}/contracts/disposable.dart', '''abstract interface class Disposable {
  Future<void> dispose();
}
''')

create_file(f'{base}/contracts/health_check.dart', '''import '../result/result.dart';

abstract interface class HealthCheck {
  String get componentName;
  Future<Result<bool>> checkHealth();
}
''')

create_file(f'{base}/contracts/feature_module.dart', '''import 'platform_service.dart';

abstract interface class FeatureModule implements PlatformService {
  void registerDependencies();
  void registerRoutes();
}
''')

create_file(f'{base}/contracts/platform_capability.dart', '''abstract interface class PlatformCapability {}

abstract interface class PlatformCapabilityRegistry {
  Iterable<PlatformCapability> capabilities();
  void register(PlatformCapability capability);
}
''')


# Bootstrap
create_file(f'{base}/bootstrap/bootstrap_phase.dart', '''enum BootstrapPhase {
  environment,
  logging,
  storage,
  settings,
  jobs,
  runtime,
  plugins,
  features,
  applicationReady,
}
''')

create_file(f'{base}/bootstrap/bootstrap_context.dart', '''import '../environment/platform_environment.dart';

class BootstrapContext {
  final PlatformEnvironment environment;

  const BootstrapContext({required this.environment});
}
''')

create_file(f'{base}/bootstrap/bootstrap_result.dart', '''import 'bootstrap_phase.dart';

class BootstrapResult {
  final bool isSuccess;
  final String? errorMessage;
  final BootstrapPhase phase;

  const BootstrapResult.success(this.phase)
      : isSuccess = true,
        errorMessage = null;

  const BootstrapResult.failure(this.phase, this.errorMessage)
      : isSuccess = false;
}
''')

create_file(f'{base}/bootstrap/bootstrap_coordinator.dart', '''import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'bootstrap_context.dart';
import 'bootstrap_phase.dart';
import '../contracts/bootstrap_task.dart';
import '../exceptions/platform_exceptions.dart';
import '../lifecycle/lifecycle_state.dart';

part 'bootstrap_coordinator.g.dart';

@riverpod
class BootstrapCoordinator extends _$BootstrapCoordinator {
  final List<BootstrapTask> _tasks = [];
  
  @override
  LifecycleState build() => LifecycleState.created;

  void registerTask(BootstrapTask task) {
    _tasks.add(task);
  }

  Future<void> execute(BootstrapContext context) async {
    state = LifecycleState.initializing;
    
    // Sort tasks by phase order
    _tasks.sort((a, b) => a.phase.index.compareTo(b.phase.index));

    for (final task in _tasks) {
      try {
        final result = await task.execute(context);
        if (!result.isSuccess) {
          state = LifecycleState.failed;
          throw InitializationException(
              'Failed during ${result.phase.name}: ${result.errorMessage}');
        }
      } catch (e, st) {
        state = LifecycleState.failed;
        throw InitializationException('Task ${task.name} failed', e, st);
      }
    }
    
    state = LifecycleState.ready;
  }
}
''')


# Lifecycle
create_file(f'{base}/lifecycle/lifecycle_state.dart', '''enum LifecycleState {
  created,
  initializing,
  ready,
  paused,
  resumed,
  stopping,
  disposed,
  failed,
}
''')


# Result
create_file(f'{base}/result/result.dart', '''import 'package:freezed_annotation/freezed_annotation.dart';

part 'result.freezed.dart';

@freezed
sealed class Result<T> with _$Result<T> {
  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(Exception exception, [StackTrace? stackTrace]) = Failure<T>;
}
''')


# Exceptions
create_file(f'{base}/exceptions/platform_exceptions.dart', '''class PlatformException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const PlatformException(this.message, [this.cause, this.stackTrace]);

  @override
  String toString() => 'PlatformException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

class InitializationException extends PlatformException {
  const InitializationException(super.message, [super.cause, super.stackTrace]);
}

class ConfigurationException extends PlatformException {
  const ConfigurationException(super.message, [super.cause, super.stackTrace]);
}

class DependencyException extends PlatformException {
  const DependencyException(super.message, [super.cause, super.stackTrace]);
}

class LifecycleException extends PlatformException {
  const LifecycleException(super.message, [super.cause, super.stackTrace]);
}
''')


# Environment
create_file(f'{base}/environment/platform_environment.dart', '''import 'package:freezed_annotation/freezed_annotation.dart';

part 'platform_environment.freezed.dart';

@freezed
class PlatformEnvironment with _$PlatformEnvironment {
  const factory PlatformEnvironment({
    required String buildMode,
    required String platform,
    required String version,
    required String packageVersion,
    @Default([]) List<String> deviceCapabilities,
    @Default([]) List<String> featureFlags,
  }) = _PlatformEnvironment;
}
''')


# Version
create_file(f'{base}/version/platform_version.dart', '''import 'package:equatable/equatable.dart';

class SemanticVersion extends Equatable {
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;
  final String? buildMetadata;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease,
    this.buildMetadata,
  });

  @override
  List<Object?> get props => [major, minor, patch, preRelease, buildMetadata];
  
  @override
  String toString() {
    var v = '$major.$minor.$patch';
    if (preRelease != null) v += '-$preRelease';
    if (buildMetadata != null) v += '+$buildMetadata';
    return v;
  }
}

class PlatformVersion extends Equatable {
  final SemanticVersion coreVersion;
  final SemanticVersion apiVersion;

  const PlatformVersion({
    required this.coreVersion,
    required this.apiVersion,
  });

  @override
  List<Object?> get props => [coreVersion, apiVersion];
}
''')

# Events
create_file(f'{base}/events/platform_event.dart', '''import '../lifecycle/lifecycle_state.dart';

abstract class PlatformEvent {
  final DateTime timestamp;
  PlatformEvent() : timestamp = DateTime.now();
}

class LifecycleEvent extends PlatformEvent {
  final LifecycleState state;
  LifecycleEvent(this.state);
}

class BootstrapEvent extends PlatformEvent {
  final String phase;
  final bool isComplete;
  BootstrapEvent({required this.phase, required this.isComplete});
}

class ErrorEvent extends PlatformEvent {
  final Exception exception;
  final StackTrace? stackTrace;
  ErrorEvent(this.exception, [this.stackTrace]);
}
''')

# Providers
create_file(f'{base}/providers/platform_providers.dart', '''import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../environment/platform_environment.dart';
import '../version/platform_version.dart';

final environmentProvider = Provider<PlatformEnvironment>((ref) {
  throw UnimplementedError('Environment must be overridden during bootstrap');
});

final platformVersionProvider = Provider<PlatformVersion>((ref) {
  throw UnimplementedError('Platform version must be overridden during bootstrap');
});
''')

# Export file
create_file('packages/platform_core/lib/platform_core.dart', '''library platform_core;

export 'src/bootstrap/bootstrap_context.dart';
export 'src/bootstrap/bootstrap_coordinator.dart';
export 'src/bootstrap/bootstrap_phase.dart';
export 'src/bootstrap/bootstrap_result.dart';

export 'src/contracts/bootstrap_task.dart';
export 'src/contracts/disposable.dart';
export 'src/contracts/feature_module.dart';
export 'src/contracts/health_check.dart';
export 'src/contracts/initializable.dart';
export 'src/contracts/lifecycle_aware.dart';
export 'src/contracts/platform_capability.dart';
export 'src/contracts/platform_service.dart';

export 'src/environment/platform_environment.dart';
export 'src/events/platform_event.dart';
export 'src/exceptions/platform_exceptions.dart';
export 'src/lifecycle/lifecycle_state.dart';
export 'src/providers/platform_providers.dart';
export 'src/result/result.dart';
export 'src/version/platform_version.dart';
''')

print("Created all files.")
