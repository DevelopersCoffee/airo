import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

enum RegionResolutionSource { sim, locale, cachedNetwork, network, unavailable }

final class RegionResolution extends Equatable {
  const RegionResolution({
    required this.countryCode,
    required this.source,
    required this.resolvedAt,
  });

  const RegionResolution.unavailable()
    : countryCode = null,
      source = RegionResolutionSource.unavailable,
      resolvedAt = null;

  final String? countryCode;
  final RegionResolutionSource source;
  final DateTime? resolvedAt;

  bool get isAvailable => countryCode != null;

  @override
  List<Object?> get props => [countryCode, source, resolvedAt];
}

final class RegionNetworkCacheEntry extends Equatable {
  const RegionNetworkCacheEntry({
    required this.countryCode,
    required this.resolvedAt,
  });

  final String countryCode;
  final DateTime resolvedAt;

  @override
  List<Object?> get props => [countryCode, resolvedAt];
}

abstract interface class RegionNetworkCache {
  Future<RegionNetworkCacheEntry?> read();
  Future<void> write(RegionNetworkCacheEntry entry);
}

typedef RegionSignal = Future<String?> Function();

/// Privacy-first country resolver.
///
/// A network lookup is reached only when SIM, locale, and a fresh cached
/// answer are all unavailable and [allowNetworkLookup] is explicitly true.
final class RegionResolver {
  RegionResolver({
    required this.simCountry,
    required this.localeCountry,
    this.networkCountry,
    this.networkCache,
    this.allowNetworkLookup = false,
    this.networkCacheTtl = const Duration(days: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RegionSignal simCountry;
  final RegionSignal localeCountry;
  final RegionSignal? networkCountry;
  final RegionNetworkCache? networkCache;
  final bool allowNetworkLookup;
  final Duration networkCacheTtl;
  final DateTime Function() _clock;

  Future<RegionResolution> resolve() async {
    final now = _clock().toUtc();
    final sim = _normalize(await simCountry());
    if (sim != null) {
      return RegionResolution(
        countryCode: sim,
        source: RegionResolutionSource.sim,
        resolvedAt: now,
      );
    }
    final locale = _normalize(await localeCountry());
    if (locale != null) {
      return RegionResolution(
        countryCode: locale,
        source: RegionResolutionSource.locale,
        resolvedAt: now,
      );
    }
    final cached = await networkCache?.read();
    final cachedCountry = _normalize(cached?.countryCode);
    if (cached != null &&
        cachedCountry != null &&
        now.difference(cached.resolvedAt.toUtc()) <= networkCacheTtl) {
      return RegionResolution(
        countryCode: cachedCountry,
        source: RegionResolutionSource.cachedNetwork,
        resolvedAt: cached.resolvedAt.toUtc(),
      );
    }
    if (!allowNetworkLookup || networkCountry == null) {
      return const RegionResolution.unavailable();
    }
    final network = _normalize(await networkCountry!());
    if (network == null) return const RegionResolution.unavailable();
    final entry = RegionNetworkCacheEntry(
      countryCode: network,
      resolvedAt: now,
    );
    await networkCache?.write(entry);
    return RegionResolution(
      countryCode: network,
      source: RegionResolutionSource.network,
      resolvedAt: now,
    );
  }

  static String? _normalize(String? value) {
    final normalized = value?.trim().toUpperCase();
    return normalized != null && RegExp(r'^[A-Z]{2}$').hasMatch(normalized)
        ? normalized
        : null;
  }
}

/// Android reads the ISO SIM country without requesting phone identity or
/// location permission. Other platforms return null and fall through to
/// locale.
final class HostPlatformRegionSignal {
  HostPlatformRegionSignal({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.airo/device_info');

  final MethodChannel _channel;

  Future<String?> simCountry() async {
    try {
      return await _channel.invokeMethod<String>('getSimCountryIso');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
