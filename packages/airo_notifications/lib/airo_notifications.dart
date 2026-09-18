export 'src/models/action.dart';
export 'src/models/alert.dart';
export 'src/models/group.dart';
export 'src/models/permission.dart';
export 'src/models/push_wake.dart';
export 'src/models/task_reference.dart';
export 'src/routing/route_normalizer.dart';
export 'src/storage/alert_store.dart';
export 'src/storage/in_memory_alert_store.dart';
export 'src/storage/preferences_alert_store.dart';
export 'src/summarization/summarizer.dart';
export 'src/engine/action_router.dart';
export 'src/engine/grouping_engine.dart';
export 'src/engine/notification_engine.dart';
export 'src/testing/fake_notification_engine.dart';

import 'src/engine/notification_engine.dart';

class AiroNotifications {
  AiroNotifications._();

  static AiroNotificationEngine? _customEngine;

  static AiroNotificationEngine get engine =>
      _customEngine ??= LocalAiroNotificationEngine();

  static set engine(AiroNotificationEngine custom) {
    _customEngine = custom;
  }
}
