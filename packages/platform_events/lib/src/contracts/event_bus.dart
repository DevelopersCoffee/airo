import 'event_publisher.dart';
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
