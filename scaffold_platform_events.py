import os

def create_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

base = 'packages/platform_events/lib/src'

# Metadata & Enums
create_file(f'{base}/event_types/event_category.dart', '''enum EventCategory {
  platform,
  runtime,
  storage,
  download,
  knowledge,
  memory,
  meeting,
  workflow,
  plugin,
  settings,
  diagnostics,
  security,
  lifecycle,
}
''')

create_file(f'{base}/event_types/event_metadata.dart', '''import 'package:equatable/equatable.dart';

class EventMetadata extends Equatable {
  final Map<String, dynamic> _data;

  const EventMetadata([Map<String, dynamic>? data]) : _data = data ?? const {};
  
  Map<String, dynamic> toMap() => Map.unmodifiable(_data);

  @override
  List<Object?> get props => [_data];
}
''')

# Contracts
create_file(f'{base}/contracts/platform_event.dart', '''import '../event_types/event_metadata.dart';
import '../event_types/event_category.dart';
import 'package:platform_core/platform_core.dart';

abstract interface class PlatformEvent {
  String get eventId;
  DateTime get timestamp;
  EventCategory get category;
  SemanticVersion get version;
  
  String? get correlationId;
  String? get sessionId;
  String? get workspaceId;
  String? get source;
  EventMetadata? get metadata;
}
''')

create_file(f'{base}/contracts/event_publisher.dart', '''import 'platform_event.dart';

abstract interface class EventPublisher {
  void publish(PlatformEvent event);
}
''')

create_file(f'{base}/contracts/event_subscriber.dart', '''import 'platform_event.dart';

typedef EventHandler<T extends PlatformEvent> = Future<void> Function(T event);

abstract interface class EventSubscriber {
  void subscribe<T extends PlatformEvent>(EventHandler<T> handler);
  void unsubscribe<T extends PlatformEvent>(EventHandler<T> handler);
}
''')

create_file(f'{base}/contracts/event_bus.dart', '''import 'event_publisher.dart';
import 'event_subscriber.dart';
import 'event_filter.dart';
import 'event_interceptor.dart';
import 'platform_event.dart';
import '../diagnostics/event_diagnostics.dart';

abstract interface class EventBus implements EventPublisher, EventSubscriber {
  void addFilter(EventFilter filter);
  void addInterceptor(EventInterceptor interceptor);
  
  List<PlatformEvent> get replayBuffer;
  EventBusDiagnostics get diagnostics;
}
''')

create_file(f'{base}/contracts/event_filter.dart', '''import 'platform_event.dart';

abstract interface class EventFilter {
  bool shouldDispatch(PlatformEvent event);
}
''')

create_file(f'{base}/contracts/event_interceptor.dart', '''import 'platform_event.dart';

abstract interface class EventInterceptor {
  PlatformEvent intercept(PlatformEvent event);
}
''')

# Event Bus Implementation
create_file(f'{base}/event_bus/default_event_bus.dart', '''import 'dart:async';
import '../contracts/event_bus.dart';
import '../contracts/platform_event.dart';
import '../contracts/event_subscriber.dart';
import '../contracts/event_filter.dart';
import '../contracts/event_interceptor.dart';
import '../diagnostics/event_diagnostics.dart';

class DefaultEventBus implements EventBus {
  final List<EventFilter> _filters = [];
  final List<EventInterceptor> _interceptors = [];
  
  // Handlers typed by event
  final Map<Type, List<Function>> _handlers = {};
  
  // Replay buffer
  final List<PlatformEvent> _replayBuffer = [];
  final int maxReplaySize;

  // Diagnostics
  int _publishedCount = 0;
  int _droppedCount = 0;

  DefaultEventBus({this.maxReplaySize = 100});

  @override
  void addFilter(EventFilter filter) {
    _filters.add(filter);
  }

  @override
  void addInterceptor(EventInterceptor interceptor) {
    _interceptors.add(interceptor);
  }

  @override
  void publish(PlatformEvent event) {
    _publishedCount++;
    
    // 1. Filter
    for (final filter in _filters) {
      if (!filter.shouldDispatch(event)) {
        _droppedCount++;
        return;
      }
    }

    // 2. Intercept (enrich)
    PlatformEvent processedEvent = event;
    for (final interceptor in _interceptors) {
      processedEvent = interceptor.intercept(processedEvent);
    }

    // 3. Add to replay buffer
    _replayBuffer.add(processedEvent);
    if (_replayBuffer.length > maxReplaySize) {
      _replayBuffer.removeAt(0);
    }

    // 4. Dispatch
    final handlers = _handlers[processedEvent.runtimeType];
    if (handlers != null) {
      for (final handler in handlers) {
        // We do not await handlers here to ensure publisher isn't blocked by slow subscribers
        // but order is preserved synchronously at dispatch time.
        scheduleMicrotask(() {
           handler(processedEvent);
        });
      }
    }
  }

  @override
  void subscribe<T extends PlatformEvent>(EventHandler<T> handler) {
    _handlers.putIfAbsent(T, () => []).add(handler);
  }

  @override
  void unsubscribe<T extends PlatformEvent>(EventHandler<T> handler) {
    final handlers = _handlers[T];
    if (handlers != null) {
      handlers.remove(handler);
      if (handlers.isEmpty) {
        _handlers.remove(T);
      }
    }
  }

  @override
  List<PlatformEvent> get replayBuffer => List.unmodifiable(_replayBuffer);

  @override
  EventBusDiagnostics get diagnostics => EventBusDiagnostics(
    activeSubscribers: _handlers.values.fold(0, (sum, list) => sum + list.length),
    publishedCount: _publishedCount,
    droppedCount: _droppedCount,
  );
}
''')

# Diagnostics
create_file(f'{base}/diagnostics/event_diagnostics.dart', '''class EventBusDiagnostics {
  final int activeSubscribers;
  final int publishedCount;
  final int droppedCount;

  const EventBusDiagnostics({
    required this.activeSubscribers,
    required this.publishedCount,
    required this.droppedCount,
  });
}
''')

# Providers
create_file(f'{base}/providers/event_providers.dart', '''import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../contracts/event_bus.dart';
import '../contracts/event_publisher.dart';
import '../event_bus/default_event_bus.dart';

final eventBusProvider = Provider<EventBus>((ref) {
  return DefaultEventBus();
});

final eventPublisherProvider = Provider<EventPublisher>((ref) {
  return ref.watch(eventBusProvider);
});
''')

# Export file
create_file('packages/platform_events/lib/platform_events.dart', '''library platform_events;

export 'src/contracts/platform_event.dart';
export 'src/contracts/event_bus.dart';
export 'src/contracts/event_publisher.dart';
export 'src/contracts/event_subscriber.dart';
export 'src/contracts/event_filter.dart';
export 'src/contracts/event_interceptor.dart';
export 'src/event_types/event_category.dart';
export 'src/event_types/event_metadata.dart';
export 'src/diagnostics/event_diagnostics.dart';
export 'src/providers/event_providers.dart';
''')

print("Created all platform_events files.")
