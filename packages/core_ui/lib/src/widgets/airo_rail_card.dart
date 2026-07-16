import 'package:flutter/material.dart';

import '../theme/airo_theme_tokens.dart';
import '../theme/app_colors.dart';
import 'tv_focusable.dart';

/// A horizontal-rail channel card: landscape thumbnail (172x104 in the
/// source design) with LIVE/quality badges, followed by a name + subtitle.
///
/// Distinct from [AiroChannelCard] (a square grid tile) — this is the card
/// used in horizontally-scrolling rails (e.g. "Top 50 India", "Live Sports").
/// Theme-aware: reads colors from [Theme.of(context)] so it renders
/// correctly under any registered [AppThemeId], not just one palette.
class AiroRailCard extends StatelessWidget {
  const AiroRailCard({
    required this.name,
    super.key,
    this.subtitle,
    this.logoUrl,
    this.initials,
    this.placeholderColor,
    this.quality,
    this.isLive = false,
    this.width = 172,
    this.thumbnailHeight = 104,
    this.onTap,
    this.onLongPress,
    this.autofocus = false,
  });

  final String name;
  final String? subtitle;
  final String? logoUrl;

  /// Fallback text (e.g. channel initials) shown when there's no logo.
  final String? initials;

  /// Background color for the thumbnail area when showing [initials].
  final Color? placeholderColor;

  /// e.g. "HD", "1080p" — shown as a badge in the thumbnail's top-right.
  final String? quality;
  final bool isLive;
  final double width;
  final double thumbnailHeight;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AiroThemeTokens>();
    final gridLine = tokens?.gridLine ?? colorScheme.outlineVariant;
    final focusColor = tokens?.success ?? colorScheme.primary;
    final qualityColor = tokens?.warning ?? colorScheme.tertiary;

    return TvFocusable(
      onSelect: onTap,
      autofocus: autofocus,
      borderRadius: 12,
      focusColor: focusColor,
      semanticLabel: isLive ? '$name, live' : name,
      semanticHint: 'Press OK to play channel',
      semanticButton: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: gridLine, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: thumbnailHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildThumbnail(colorScheme),
                    if (isLive)
                      Positioned(top: 7, left: 7, child: _LiveBadge()),
                    if (quality != null)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: _QualityBadge(
                          quality: quality!,
                          color: qualityColor,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ColorScheme colorScheme) {
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return Image.network(
        logoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(colorScheme),
      );
    }
    return _buildPlaceholder(colorScheme);
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: placeholderColor ?? colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(
        initials ?? (name.isNotEmpty ? name[0].toUpperCase() : '?'),
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: Color(0xE0FFFFFF),
          letterSpacing: -0.5,
          shadows: [Shadow(blurRadius: 8, color: Color(0x73000000))],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.live,
        borderRadius: BorderRadius.circular(100),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(),
          SizedBox(width: 3),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 1,
        end: 0.25,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.quality, required this.color});

  final String quality;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x8C000000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        quality,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}
