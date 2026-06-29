import 'package:uuid/uuid.dart';
import 'package:platform_events/platform_events.dart';
import '../contracts/settings_observer.dart';
import '../contracts/setting_definition.dart';
import 'settings_changed_event.dart';

class EventBusSettingsObserver implements SettingsObserver {
  final EventPublisher _publisher;
  final _uuid = const Uuid();

  EventBusSettingsObserver(this._publisher);

  @override
  void onSettingChanged<T>(SettingDefinition<T> setting, T oldValue, T newValue) {
    _publisher.publish(
      SettingsChangedEvent<T>(
        eventId: _uuid.v4(),
        setting: setting,
        oldValue: oldValue,
        newValue: newValue,
      )
    );
  }
}
