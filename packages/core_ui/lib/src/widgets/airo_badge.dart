import 'package:flutter/material.dart';

import '../theme/airo_colors.dart';

enum AiroBadgeVariant { live, pro, success, warning, error, neutral, recent }

enum AiroBadgeSize { sm, md }

class AiroBadge extends StatefulWidget {
  const AiroBadge({
    required this.label,
    super.key,
    this.variant = AiroBadgeVariant.neutral,
    this.size = AiroBadgeSize.md,
    this.pulse = false,
  });

  const AiroBadge.live({super.key, this.pulse = true})
    : label = 'LIVE',
      variant = AiroBadgeVariant.live,
      size = AiroBadgeSize.md;

  const AiroBadge.pro({super.key})
    : label = 'PRO',
      variant = AiroBadgeVariant.pro,
      size = AiroBadgeSize.sm,
      pulse = false;

  final String label;
  final AiroBadgeVariant variant;
  final AiroBadgeSize size;
  final bool pulse;

  @override
  State<AiroBadge> createState() => _AiroBadgeState();
}

class _AiroBadgeState extends State<AiroBadge>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    if (widget.pulse && widget.variant == AiroBadgeVariant.live) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors();
    final isSm = widget.size == AiroBadgeSize.sm;
    final padding = isSm
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
    final fontSize = isSm ? 9.0 : 11.0;
    final isRound = widget.variant == AiroBadgeVariant.live;
    final radius = isRound ? 4.0 : 9999.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: widget.variant == AiroBadgeVariant.live && widget.pulse
            ? const [BoxShadow(blurRadius: 8, color: AiroColors.liveGlow)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.variant == AiroBadgeVariant.live) ...[
            _LiveDot(controller: _pulseController),
            const SizedBox(width: 4),
          ],
          Text(
            widget.label,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  (Color bg, Color fg) _colors() {
    return switch (widget.variant) {
      AiroBadgeVariant.live => (AiroColors.live, Colors.white),
      AiroBadgeVariant.success => (
        AiroColors.cyberTertiary,
        AiroColors.cyberOnPrimary,
      ),
      AiroBadgeVariant.warning => (
        const Color(0xFFFF9800),
        AiroColors.cyberOnPrimary,
      ),
      AiroBadgeVariant.error => (AiroColors.cyberError, Colors.white),
      AiroBadgeVariant.pro => (
        AiroColors.cyberSecondary,
        AiroColors.cyberOnPrimary,
      ),
      AiroBadgeVariant.neutral => (
        AiroColors.cyberPrimary.withValues(alpha: 0.15),
        AiroColors.cyberText,
      ),
      AiroBadgeVariant.recent => (
        AiroColors.cyberTertiary.withValues(alpha: 0.15),
        AiroColors.cyberTertiary,
      ),
    };
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({this.controller});

  final AnimationController? controller;

  @override
  Widget build(BuildContext context) {
    Widget dot = Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );

    if (controller != null) {
      dot = FadeTransition(opacity: controller!, child: dot);
    }

    return dot;
  }
}
