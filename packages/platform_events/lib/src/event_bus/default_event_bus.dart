import 'dart:async';
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
