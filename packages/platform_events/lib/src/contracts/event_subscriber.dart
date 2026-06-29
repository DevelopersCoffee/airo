import 'platform_event.dart';

typedef EventHandler<T extends PlatformEvent> = Future<void> Function(T event);

abstract interface class EventSubscriber {
  void subscribe<T extends PlatformEvent>(EventHandler<T> handler);
  void unsubscribe<T extends PlatformEvent>(EventHandler<T> handler);
}
