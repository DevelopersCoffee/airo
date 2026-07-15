import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Optimized channel logo widget that decodes images at display size.
///
/// Uses [CachedNetworkImage] with [memCacheWidth]/[memCacheHeight] set to
/// the cell pixel size multiplied by the device pixel ratio. This prevents
/// full-resolution decode for 10k+ channel logos, significantly reducing
/// GPU memory usage on TV and mobile.
class ChannelLogo extends StatelessWidget {
  /// The URL of the channel logo image. If null or empty, the placeholder
  /// is shown.
  final String? logoUrl;

  /// The channel name, used to derive the placeholder letter.
  final String channelName;

  /// The display size of the logo in logical pixels.
  /// Both width and height are set to this value (square).
  final double size;

  /// How the image should be inscribed into the box.
  final BoxFit fit;

  /// Border radius applied to the image and placeholder.
  final double borderRadius;

  /// Whether this is an audio-only channel (changes the fallback icon).
  final bool isAudioOnly;

  const ChannelLogo({
    super.key,
    required this.logoUrl,
    required this.channelName,
    this.size = 48,
    this.fit = BoxFit.cover,
    this.borderRadius = 6,
    this.isAudioOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (size * dpr).ceil();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: _hasValidUrl
            ? CachedNetworkImage(
                imageUrl: logoUrl!,
                memCacheWidth: cacheSize,
                memCacheHeight: cacheSize,
                maxWidthDiskCache: cacheSize,
                maxHeightDiskCache: cacheSize,
                fit: fit,
                placeholder: (_, _) => _buildPlaceholder(context),
                errorWidget: (_, _, _) => _buildPlaceholder(context),
              )
            : _buildPlaceholder(context),
      ),
    );
  }

  bool get _hasValidUrl => logoUrl != null && logoUrl!.isNotEmpty;

  /// Placeholder: colored box with the first letter of the channel name
  /// or a fallback icon.
  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final letter = channelName.isNotEmpty ? channelName[0].toUpperCase() : '?';
    // Derive a stable hue from the channel name for visual variety.
    final hue = (channelName.hashCode % 360).abs().toDouble();
    final bgColor = HSLColor.fromAHSL(1, hue, 0.3, 0.25).toColor();

    return Container(
      color: bgColor,
      child: Center(
        child: size >= 40
            ? Text(
                letter,
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w600,
                ),
              )
            : Icon(
                isAudioOnly ? Icons.radio : Icons.live_tv,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                size: size * 0.5,
              ),
      ),
    );
  }
}
