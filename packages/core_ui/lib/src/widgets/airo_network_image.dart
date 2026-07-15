import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:platform_device_profile/platform_device_profile.dart';

typedef AiroImageFallbackBuilder =
    Widget Function(BuildContext context, Object error, StackTrace? stackTrace);

const String kAiroImageCacheTelemetrySchemaVersion = '1.0.0';

/// Validates remote artwork URLs before product UI starts image fetches.
class AiroNetworkImageUrlPolicy {
  const AiroNetworkImageUrlPolicy._();

  static const String unsupportedUrlCode = 'unsupported_network_image_url';

  static Uri? normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return null;

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return null;

    return uri;
  }

  static bool accepts(String value) => normalize(value) != null;
}

/// Network image that decodes near its rendered size.
class AiroNetworkImage extends StatelessWidget {
  const AiroNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.filterQuality = FilterQuality.low,
    this.placeholderBuilder,
    this.errorBuilder,
    this.maxDecodeDimension = 1024,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final FilterQuality filterQuality;
  final WidgetBuilder? placeholderBuilder;
  final AiroImageFallbackBuilder? errorBuilder;
  final int maxDecodeDimension;

  @override
  Widget build(BuildContext context) {
    final normalizedUri = AiroNetworkImageUrlPolicy.normalize(url);
    if (normalizedUri == null) {
      final error = ArgumentError(AiroNetworkImageUrlPolicy.unsupportedUrlCode);
      return errorBuilder?.call(context, error, null) ??
          const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = _cacheDimension(
          explicitSize: width,
          constrainedSize: constraints.maxWidth,
          devicePixelRatio: devicePixelRatio,
        );
        final cacheHeight = _cacheDimension(
          explicitSize: height,
          constrainedSize: constraints.maxHeight,
          devicePixelRatio: devicePixelRatio,
        );

        return Image.network(
          normalizedUri.toString(),
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          semanticLabel: semanticLabel,
          excludeFromSemantics: excludeFromSemantics,
          filterQuality: filterQuality,
          cacheWidth: _clampCacheDimension(cacheWidth),
          cacheHeight: _clampCacheDimension(cacheHeight),
          loadingBuilder: placeholderBuilder == null
              ? null
              : (context, child, progress) {
                  if (progress == null) return child;
                  return placeholderBuilder!(context);
                },
          errorBuilder: errorBuilder == null
              ? null
              : (context, error, stackTrace) {
                  return errorBuilder!(context, error, stackTrace);
                },
        );
      },
    );
  }

  int? _cacheDimension({
    required double? explicitSize,
    required double constrainedSize,
    required double devicePixelRatio,
  }) {
    final logicalSize = explicitSize ?? constrainedSize;
    if (!logicalSize.isFinite || logicalSize <= 0) return null;
    return (logicalSize * devicePixelRatio).ceil();
  }

  int? _clampCacheDimension(int? value) {
    if (value == null) return null;
    return math.max(1, math.min(value, maxDecodeDimension));
  }
}

class AiroImageCacheSnapshot {
  const AiroImageCacheSnapshot({
    required this.capturedAt,
    required this.currentEntryCount,
    required this.currentSizeBytes,
    required this.liveImageCount,
    required this.pendingImageCount,
    required this.maximumEntryCount,
    required this.maximumSizeBytes,
    this.schemaVersion = kAiroImageCacheTelemetrySchemaVersion,
  });

  final String schemaVersion;
  final DateTime capturedAt;
  final int currentEntryCount;
  final int currentSizeBytes;
  final int liveImageCount;
  final int pendingImageCount;
  final int maximumEntryCount;
  final int maximumSizeBytes;

  int get currentSizeMb =>
      (currentSizeBytes / AiroRuntimeMemoryBudgetPolicy.bytesPerMb).ceil();

  int get maximumSizeMb =>
      (maximumSizeBytes / AiroRuntimeMemoryBudgetPolicy.bytesPerMb).ceil();

  static AiroImageCacheSnapshot capture({
    ImageCache? imageCache,
    DateTime? capturedAt,
  }) {
    final cache = imageCache ?? PaintingBinding.instance.imageCache;
    return AiroImageCacheSnapshot(
      capturedAt: (capturedAt ?? DateTime.now()).toUtc(),
      currentEntryCount: cache.currentSize,
      currentSizeBytes: cache.currentSizeBytes,
      liveImageCount: cache.liveImageCount,
      pendingImageCount: cache.pendingImageCount,
      maximumEntryCount: cache.maximumSize,
      maximumSizeBytes: cache.maximumSizeBytes,
    );
  }

  AiroImageCacheBudgetEvaluation evaluate({
    AiroRuntimeMemoryBudget budget =
        AiroRuntimeMemoryBudgetPolicy.androidTvConstrainedBudget,
  }) {
    final violations = <AiroRuntimeMemoryBudgetViolationCode>[];
    if (currentSizeBytes >
        budget.imageCacheMb * AiroRuntimeMemoryBudgetPolicy.bytesPerMb) {
      violations.add(AiroRuntimeMemoryBudgetViolationCode.imageCacheExceeded);
    }
    if (currentEntryCount > budget.imageCacheEntries) {
      violations.add(AiroRuntimeMemoryBudgetViolationCode.imageCacheExceeded);
    }
    return AiroImageCacheBudgetEvaluation(
      snapshot: this,
      budget: budget,
      violations: violations.isEmpty
          ? const [AiroRuntimeMemoryBudgetViolationCode.accepted]
          : violations.toSet(),
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'capturedAt': capturedAt.toIso8601String(),
      'currentEntryCount': currentEntryCount,
      'currentSizeBytes': currentSizeBytes,
      'currentSizeMb': currentSizeMb,
      'liveImageCount': liveImageCount,
      'pendingImageCount': pendingImageCount,
      'maximumEntryCount': maximumEntryCount,
      'maximumSizeBytes': maximumSizeBytes,
      'maximumSizeMb': maximumSizeMb,
    };
  }
}

class AiroImageCacheBudgetEvaluation {
  AiroImageCacheBudgetEvaluation({
    required this.snapshot,
    required this.budget,
    required Iterable<AiroRuntimeMemoryBudgetViolationCode> violations,
  }) : violations = List.unmodifiable(violations);

  final AiroImageCacheSnapshot snapshot;
  final AiroRuntimeMemoryBudget budget;
  final List<AiroRuntimeMemoryBudgetViolationCode> violations;

  bool get accepted =>
      violations.length == 1 &&
      violations.first == AiroRuntimeMemoryBudgetViolationCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': snapshot.schemaVersion,
      'budgetId': budget.budgetId,
      'accepted': accepted,
      'violations': violations
          .map((violation) => violation.stableId)
          .toList(growable: false),
      'imageCache': snapshot.toPublicMap(),
      'limits': {
        'imageCacheEntries': budget.imageCacheEntries,
        'imageCacheMb': budget.imageCacheMb,
      },
    };
  }
}

/// Shared image cache budget helpers for constrained device profiles.
class AiroImageCacheBudget {
  const AiroImageCacheBudget._();

  static const int androidTvMaxEntries =
      AiroRuntimeMemoryBudgetPolicy.constrainedTvImageCacheEntries;
  static const int androidTvMaxBytes =
      AiroRuntimeMemoryBudgetPolicy.constrainedTvImageCacheMb *
      AiroRuntimeMemoryBudgetPolicy.bytesPerMb;

  static void configureAndroidTv({
    AiroRuntimeMemoryBudget? memoryBudget,
    int? maximumSize,
    int? maximumSizeBytes,
  }) {
    final effectiveBudget =
        memoryBudget ??
        AiroRuntimeMemoryBudgetPolicy.androidTvConstrainedBudget;
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSize = maximumSize ?? effectiveBudget.imageCacheEntries;
    imageCache.maximumSizeBytes =
        maximumSizeBytes ??
        effectiveBudget.imageCacheMb * AiroRuntimeMemoryBudgetPolicy.bytesPerMb;
  }
}
