import 'package:flutter_test/flutter_test.dart';
import 'package:platform_events/platform_events.dart';
import 'package:platform_core/platform_core.dart' hide PlatformEvent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_events/src/event_bus/default_event_bus.dart';

class TestEvent implements PlatformEvent {
  @override
  final String eventId = 'test-1';
  @override
  final DateTime timestamp = DateTime.now();
  @override
  final EventCategory category = EventCategory.platform;
  @override
  final SemanticVersion version = const SemanticVersion(major: 1, minor: 0, patch: 0);

  @override
  final String? correlationId;
  @override
  final String? sessionId = null;
  @override
  final String? workspaceId = null;
  @override
  final String? source = null;
  @override
  final EventMetadata? metadata = null;

  TestEvent({this.correlationId});
}

class TestFilter implements EventFilter {
  @override
  bool shouldDispatch(PlatformEvent event) {
    // only dispatch events that have correlationId
    return event.correlationId != null;
  }
}

class TestInterceptor implements EventInterceptor {
  @override
  PlatformEvent intercept(PlatformEvent event) {
    if (event is TestEvent && event.correlationId == 'intercept-me') {
      return TestEvent(correlationId: 'intercepted');
    }
    return event;
  }
}

void main() {
  group('DefaultEventBus', () {
    test('Subscribes and dispatches events asynchronously but strictly ordered', () async {
      final bus = DefaultEventBus();
      bool handlerCalled = false;
      
      bus.subscribe<TestEvent>((event) async {
        handlerCalled = true;
        expect(event.correlationId, '123');
      });

      bus.publish(TestEvent(correlationId: '123'));
      
      // Since dispatch uses scheduleMicrotask, it hasn't run yet
      expect(handlerCalled, false);
      
      // Let microtasks flush
      await Future.delayed(Duration.zero);
      expect(handlerCalled, true);
    });

    test('Filters drop events appropriately', () async {
      final bus = DefaultEventBus();
      bus.addFilter(TestFilter());
      
      int callCount = 0;
      bus.subscribe<TestEvent>((event) async {
        callCount++;
      });

      bus.publish(TestEvent()); // No correlationId, should be filtered
      bus.publish(TestEvent(correlationId: 'valid')); // Should pass
      
      await Future.delayed(Duration.zero);
      
      expect(callCount, 1);
      expect(bus.diagnostics.publishedCount, 2);
      expect(bus.diagnostics.droppedCount, 1);
    });

    test('Interceptors modify events before dispatch', () async {
      final bus = DefaultEventBus();
      bus.addInterceptor(TestInterceptor());
      
      String? receivedCorrelationId;
      bus.subscribe<TestEvent>((event) async {
        receivedCorrelationId = event.correlationId;
      });

      bus.publish(TestEvent(correlationId: 'intercept-me'));
      
      await Future.delayed(Duration.zero);
      expect(receivedCorrelationId, 'intercepted');
    });

    test('Replay buffer limits correctly', () {
      final bus = DefaultEventBus(maxReplaySize: 2);
      
      bus.publish(TestEvent(correlationId: '1'));
      bus.publish(TestEvent(correlationId: '2'));
      bus.publish(TestEvent(correlationId: '3'));
      
      expect(bus.replayBuffer.length, 2);
      expect(bus.replayBuffer[0].correlationId, '2');
      expect(bus.replayBuffer[1].correlationId, '3');
    });
  });

  group('Providers', () {
    test('eventBusProvider resolves to an EventBus instance', () {
      final container = ProviderContainer();
      final bus = container.read(eventBusProvider);
      final publisher = container.read(eventPublisherProvider);
      
      expect(bus, isNotNull);
      expect(publisher, equals(bus));
    });
  });
}
