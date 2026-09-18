import 'dart:async';
import '../models/action.dart';

class ActionRouter {
  final StreamController<AiroNotificationActionEvent> _actionController =
      StreamController<AiroNotificationActionEvent>.broadcast();

  Stream<AiroNotificationActionEvent> get onAction => _actionController.stream;

  void dispatch(AiroNotificationActionEvent event) {
    if (!_actionController.isClosed) {
      _actionController.add(event);
    }
  }

  void dispose() {
    _actionController.close();
  }
}
