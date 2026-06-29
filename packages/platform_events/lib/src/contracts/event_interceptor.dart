import 'platform_event.dart';

abstract interface class EventInterceptor {
  PlatformEvent intercept(PlatformEvent event);
}
