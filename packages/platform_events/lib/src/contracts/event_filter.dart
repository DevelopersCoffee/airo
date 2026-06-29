import 'platform_event.dart';

abstract interface class EventFilter {
  bool shouldDispatch(PlatformEvent event);
}
