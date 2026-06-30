abstract class ExtensionLifecycle {
  const ExtensionLifecycle();

  static const ExtensionLifecycle discovered = DiscoveredState();
  static const ExtensionLifecycle validated = ValidatedState();
  static const ExtensionLifecycle resolved = ResolvedState();
  static const ExtensionLifecycle composed = ComposedState();
  static const ExtensionLifecycle activated = ActivatedState();
  static const ExtensionLifecycle running = RunningState();
  static const ExtensionLifecycle suspended = SuspendedState();
  static const ExtensionLifecycle disabled = DisabledState();
  static const ExtensionLifecycle unloaded = UnloadedState();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ExtensionLifecycle && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
  
  @override
  String toString() => '$runtimeType';
}

class DiscoveredState extends ExtensionLifecycle {
  const DiscoveredState();
}

class ValidatedState extends ExtensionLifecycle {
  const ValidatedState();
}

class ResolvedState extends ExtensionLifecycle {
  const ResolvedState();
}

class ComposedState extends ExtensionLifecycle {
  const ComposedState();
}

class ActivatedState extends ExtensionLifecycle {
  const ActivatedState();
}

class RunningState extends ExtensionLifecycle {
  const RunningState();
}

class SuspendedState extends ExtensionLifecycle {
  const SuspendedState();
}

class DisabledState extends ExtensionLifecycle {
  const DisabledState();
}

class UnloadedState extends ExtensionLifecycle {
  const UnloadedState();
}
