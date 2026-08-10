import 'package:flutter/material.dart';

import '../theme/airo_colors.dart';
import '../theme/airo_spacing.dart';

class AiroChannelCard extends StatefulWidget {
  const AiroChannelCard({
    required this.name,
    super.key,
    this.logoUrl,
    this.group,
    this.isPlaying = false,
    this.isAudioOnly = false,
    this.isTv = false,
    this.onTap,
    this.onLongPress,
  });

  final String name;
  final String? logoUrl;
  final String? group;
  final bool isPlaying;
  final bool isAudioOnly;
  final bool isTv;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<AiroChannelCard> createState() => _AiroChannelCardState();
}

class _AiroChannelCardState extends State<AiroChannelCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final w = widget.isTv ? AiroSpacing.tvChannelCardW : 120.0;
    final h = widget.isTv ? AiroSpacing.tvChannelCardH : 92.0;
    final nameFontSize = widget.isTv ? 14.0 : 11.0;

    final borderColor = widget.isPlaying
        ? AiroColors.cyberTertiary
        : _focused
        ? AiroColors.cyberPrimary
        : AiroColors.cyberGridLine;
    final borderWidth = (widget.isPlaying || _focused) ? 2.0 : 1.0;

    return Focus(
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: w,
          height: h,
          padding: widget.isTv
              ? const EdgeInsets.fromLTRB(8, 12, 8, 10)
              : const EdgeInsets.fromLTRB(6, 8, 6, 8),
          decoration: BoxDecoration(
            color: widget.isPlaying
                ? AiroColors.cyberTertiary.withValues(alpha: 0.08)
                : AiroColors.cyberSurfaceSolid,
            border: Border.all(color: borderColor, width: borderWidth),
            borderRadius: AiroSpacing.borderRadiusSm,
            boxShadow: _focused
                ? const [
                    BoxShadow(spreadRadius: 3, color: AiroColors.cyberPrimary),
                    BoxShadow(blurRadius: 16, color: AiroColors.cyberGlow),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildLogo()),
              _buildLabel(nameFontSize),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    if (widget.logoUrl != null) {
      return Center(
        child: Image.network(
          widget.logoUrl!,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _buildPlaceholder(),
        ),
      );
    }
    return Center(child: _buildPlaceholder());
  }

  Widget _buildPlaceholder() {
    final size = widget.isTv ? 48.0 : 32.0;
    final iconSize = widget.isTv ? 22.0 : 16.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AiroColors.cyberPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Icon(
          widget.isAudioOnly ? Icons.music_note : Icons.play_arrow,
          size: iconSize,
          color: AiroColors.cyberMutedText,
        ),
      ),
    );
  }

  Widget _buildLabel(double fontSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AiroColors.cyberText,
            fontSize: fontSize,
            fontWeight: widget.isPlaying ? FontWeight.w600 : FontWeight.w400,
            height: 1.3,
          ),
        ),
        if (widget.isPlaying)
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Text(
              '● NOW PLAYING',
              style: TextStyle(
                color: AiroColors.cyberTertiary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
      ],
    );
  }
}
