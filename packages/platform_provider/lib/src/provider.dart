
import 'package:platform_identity/platform_identity.dart';

class ProviderDescriptor {
  final ProviderId id;
  final String version;
  final int priority;
  final List<String> capabilities;
  final List<String> supportedFormats;
  final List<String> supportedPlatforms;

  const ProviderDescriptor({
    required this.id,
    required this.version,
    required this.priority,
    required this.capabilities,
    required this.supportedFormats,
    required this.supportedPlatforms,
  });
}

abstract class PlatformProvider {
  ProviderDescriptor get descriptor;
}

class ProviderRegistry {
  final Map<ProviderId, PlatformProvider> _providers = {};

  void register(PlatformProvider provider) {
    _providers[provider.descriptor.id] = provider;
  }

  T? find<T extends PlatformProvider>() {
    for (final provider in _providers.values) {
      if (provider is T) return provider;
    }
    return null;
  }

  List<T> findAll<T extends PlatformProvider>() {
    return _providers.values.whereType<T>().toList();
  }

  List<PlatformProvider> findByCapability(String capability) {
    return _providers.values.where((p) => p.descriptor.capabilities.contains(capability)).toList();
  }

  List<PlatformProvider> findByFormat(String format) {
    return _providers.values.where((p) => p.descriptor.supportedFormats.contains(format)).toList();
  }

  List<PlatformProvider> findByPriority() {
    final list = _providers.values.toList();
    list.sort((a, b) => b.descriptor.priority.compareTo(a.descriptor.priority));
    return list;
  }
}
