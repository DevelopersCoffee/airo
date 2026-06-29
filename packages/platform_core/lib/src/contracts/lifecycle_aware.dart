import '../lifecycle/lifecycle_state.dart';

abstract interface class LifecycleAware {
  Future<void> onLifecycleStateChanged(LifecycleState state);
}
