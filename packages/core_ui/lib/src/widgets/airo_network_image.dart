import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:platform_device_profile/platform_device_profile.dart';

typedef AiroImageFallbackBuilder =
    Widget Function(BuildContext context, Object error, StackTrace? stackTrace);

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
          url,
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
