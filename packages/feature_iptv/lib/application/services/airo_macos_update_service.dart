import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:url_launcher/url_launcher.dart';

const String kAiroMacosCurrentVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '2.0.0',
);

const String kAiroMacosLatestReleaseApiUrl =
    'https://api.github.com/repos/DevelopersCoffee/airo/releases/latest';
const String kAiroMacosReleasesUrl =
    'https://github.com/DevelopersCoffee/airo/releases';

enum AiroMacosUpdateAvailability { available, upToDate, unavailable }

class AiroMacosUpdateResult {
  const AiroMacosUpdateResult({
    required this.availability,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseName,
    required this.releaseUrl,
    this.assetUrl,
    this.detail,
  });

  final AiroMacosUpdateAvailability availability;
  final String currentVersion;
  final String? latestVersion;
  final String releaseName;
  final Uri releaseUrl;
  final Uri? assetUrl;
  final String? detail;

  bool get hasUpdate => availability == AiroMacosUpdateAvailability.available;
}

class AiroMacosUpdateService {
  AiroMacosUpdateService(this._dio);

  final Dio _dio;

  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  Future<AiroMacosUpdateResult> checkLatest({
    String currentVersion = kAiroMacosCurrentVersion,
  }) async {
    if (!isSupportedPlatform) {
      return AiroMacosUpdateResult(
        availability: AiroMacosUpdateAvailability.unavailable,
        currentVersion: currentVersion,
        latestVersion: null,
        releaseName: 'Airo TV',
        releaseUrl: Uri.parse(kAiroMacosReleasesUrl),
        detail: 'Update checks are available in the macOS app.',
      );
    }

    final response = await _dio.getUri<Map<String, dynamic>>(
      Uri.parse(kAiroMacosLatestReleaseApiUrl),
      options: Options(
        headers: const {'Accept': 'application/vnd.github+json'},
      ),
    );
    final payload = response.data;
    if (payload == null) {
      throw const FormatException('GitHub release response was empty.');
    }

    return parseLatestReleasePayload(payload, currentVersion: currentVersion);
  }

  Future<bool> openRelease(Uri releaseUrl) {
    return launchUrl(releaseUrl, mode: LaunchMode.externalApplication);
  }

  @visibleForTesting
  static AiroMacosUpdateResult parseLatestReleasePayload(
    Map<String, dynamic> payload, {
    required String currentVersion,
  }) {
    final tagName = payload['tag_name'] as String?;
    final releaseName =
        payload['name'] as String? ?? tagName ?? 'Latest Airo TV release';
    final releaseUrl =
        _absoluteUri(payload['html_url'] as String?) ??
        Uri.parse(kAiroMacosReleasesUrl);
    final latestVersion = _AiroReleaseVersion.tryExtract([
      tagName,
      releaseName,
      ..._assetNames(payload),
    ]);
    final current = _AiroReleaseVersion.tryParse(currentVersion);
    final macosAsset = _findMacosAsset(payload);

    if (latestVersion == null || current == null) {
      return AiroMacosUpdateResult(
        availability: AiroMacosUpdateAvailability.unavailable,
        currentVersion: currentVersion,
        latestVersion: latestVersion?.label,
        releaseName: releaseName,
        releaseUrl: releaseUrl,
        assetUrl: macosAsset?.downloadUrl,
        detail: 'The latest release version could not be read.',
      );
    }

    if (latestVersion.compareTo(current) <= 0) {
      return AiroMacosUpdateResult(
        availability: AiroMacosUpdateAvailability.upToDate,
        currentVersion: currentVersion,
        latestVersion: latestVersion.label,
        releaseName: releaseName,
        releaseUrl: releaseUrl,
        assetUrl: macosAsset?.downloadUrl,
      );
    }

    if (macosAsset == null) {
      return AiroMacosUpdateResult(
        availability: AiroMacosUpdateAvailability.unavailable,
        currentVersion: currentVersion,
        latestVersion: latestVersion.label,
        releaseName: releaseName,
        releaseUrl: releaseUrl,
        detail: 'The latest release does not include a macOS app yet.',
      );
    }

    return AiroMacosUpdateResult(
      availability: AiroMacosUpdateAvailability.available,
      currentVersion: currentVersion,
      latestVersion: latestVersion.label,
      releaseName: releaseName,
      releaseUrl: releaseUrl,
      assetUrl: macosAsset.downloadUrl,
    );
  }

  static List<String?> _assetNames(Map<String, dynamic> payload) {
    final assets = payload['assets'];
    if (assets is! List) {
      return const [];
    }
    return [
      for (final asset in assets)
        if (asset is Map<String, dynamic>) asset['name'] as String?,
    ];
  }

  static _MacosReleaseAsset? _findMacosAsset(Map<String, dynamic> payload) {
    final assets = payload['assets'];
    if (assets is! List) {
      return null;
    }

    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) {
        continue;
      }
      final name = asset['name'] as String?;
      final downloadUrl = _absoluteUri(
        asset['browser_download_url'] as String?,
      );
      if (name == null || downloadUrl == null) {
        continue;
      }
      final normalizedName = name.toLowerCase();
      final isMacosArtifact =
          normalizedName.contains('macos') &&
          (normalizedName.endsWith('.zip') || normalizedName.endsWith('.dmg'));
      if (isMacosArtifact) {
        return _MacosReleaseAsset(downloadUrl: downloadUrl);
      }
    }

    return null;
  }

  static Uri? _absoluteUri(String? value) {
    final uri = Uri.tryParse(value ?? '');
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    return uri;
  }
}

class _MacosReleaseAsset {
  const _MacosReleaseAsset({required this.downloadUrl});

  final Uri downloadUrl;
}

class _AiroReleaseVersion implements Comparable<_AiroReleaseVersion> {
  const _AiroReleaseVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.label,
  });

  final int major;
  final int minor;
  final int patch;
  final String label;

  static final RegExp _versionPattern = RegExp(r'(\d+)\.(\d+)\.(\d+)');

  static _AiroReleaseVersion? tryParse(String value) {
    final match = _versionPattern.firstMatch(value);
    if (match == null) {
      return null;
    }
    return _AiroReleaseVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      label: '${match.group(1)}.${match.group(2)}.${match.group(3)}',
    );
  }

  static _AiroReleaseVersion? tryExtract(Iterable<String?> values) {
    for (final value in values) {
      if (value == null) {
        continue;
      }
      final version = tryParse(value);
      if (version != null) {
        return version;
      }
    }
    return null;
  }

  @override
  int compareTo(_AiroReleaseVersion other) {
    final majorDiff = major.compareTo(other.major);
    if (majorDiff != 0) {
      return majorDiff;
    }
    final minorDiff = minor.compareTo(other.minor);
    if (minorDiff != 0) {
      return minorDiff;
    }
    return patch.compareTo(other.patch);
  }
}
