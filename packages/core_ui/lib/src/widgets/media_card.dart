import 'package:flutter/material.dart';

import 'airo_rail_card.dart';

/// Presentation variants for [MediaCard].
///
/// One card component serves every content type (spec §4.2): variant
/// controls size, aspect, and badge set — never a separate widget per
/// content type. Additional variants (portrait, continueWatching) are
/// added here when the first call site needs them.
enum MediaCardVariant {
  /// Small rail card (140×84 thumbnail area).
  compact,

  /// The default 172×104 landscape rail card from the source design.
  standard,

  /// Large featured banner card (320×180 thumbnail area).
  hero,

  /// Standard size with the pulsing LIVE badge forced on.
  live,
}

/// The single reusable media card: channel, movie, show — one widget.
///
/// Wraps [AiroRailCard] (which owns the visual treatment: focus scaling,
/// badges, initials fallback) and maps [variant] to concrete dimensions.
class MediaCard extends StatelessWidget {
  const MediaCard({
    required this.name,
    super.key,
    this.variant = MediaCardVariant.standard,
    this.subtitle,
    this.logoUrl,
    this.initials,
    this.placeholderColor,
    this.quality,
    this.isLive = false,
    this.onTap,
    this.onLongPress,
    this.autofocus = false,
  });

  final String name;
  final MediaCardVariant variant;
  final String? subtitle;
  final String? logoUrl;
  final String? initials;
  final Color? placeholderColor;
  final String? quality;
  final bool isLive;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final (width, thumbnailHeight) = switch (variant) {
      MediaCardVariant.compact => (140.0, 84.0),
      MediaCardVariant.standard || MediaCardVariant.live => (172.0, 104.0),
      MediaCardVariant.hero => (320.0, 180.0),
    };
    return AiroRailCard(
      name: name,
      subtitle: subtitle,
      logoUrl: logoUrl,
      initials: initials,
      placeholderColor: placeholderColor,
      quality: quality,
      isLive: isLive || variant == MediaCardVariant.live,
      width: width,
      thumbnailHeight: thumbnailHeight,
      onTap: onTap,
      onLongPress: onLongPress,
      autofocus: autofocus,
    );
  }
}
