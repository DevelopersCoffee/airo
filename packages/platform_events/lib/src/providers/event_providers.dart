import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../contracts/event_bus.dart';
import '../contracts/event_publisher.dart';
import '../event_bus/default_event_bus.dart';

final eventBusProvider = Provider<EventBus>((ref) {
  return DefaultEventBus();
});

final eventPublisherProvider = Provider<EventPublisher>((ref) {
  return ref.watch(eventBusProvider);
});
