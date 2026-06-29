import 'platform_event.dart';

abstract interface class EventPublisher {
  void publish(PlatformEvent event);
}
