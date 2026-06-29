abstract interface class PlatformCapability {}

abstract interface class PlatformCapabilityRegistry {
  Iterable<PlatformCapability> capabilities();
  void register(PlatformCapability capability);
}
