import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Design-system effects tokens: shadows, transitions, borders, gradients.
@immutable
class AiroEffects extends ThemeExtension<AiroEffects> {
  const AiroEffects({
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
    required this.shadowGlow,
    required this.shadowGlowPrimary,
    required this.shadowLive,
    required this.shadowFocus,
    required this.shadowFocusTv,
    required this.overlayDark,
    required this.overlayLight,
    required this.borderGrid,
    required this.borderOutline,
    required this.borderPrimary,
    required this.gradientPlayer,
    required this.gradientBackground,
    required this.transitionFast,
    required this.transitionStd,
    required this.transitionSlow,
  });

  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> shadowLg;
  final List<BoxShadow> shadowGlow;
  final List<BoxShadow> shadowGlowPrimary;
  final List<BoxShadow> shadowLive;
  final List<BoxShadow> shadowFocus;
  final List<BoxShadow> shadowFocusTv;
  final Color overlayDark;
  final Color overlayLight;
  final BorderSide borderGrid;
  final BorderSide borderOutline;
  final BorderSide borderPrimary;
  final LinearGradient gradientPlayer;
  final LinearGradient gradientBackground;
  final Duration transitionFast;
  final Duration transitionStd;
  final Duration transitionSlow;

  static const cyber = AiroEffects(
    shadowSm: [
      BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x4D000000)),
    ],
    shadowMd: [
      BoxShadow(offset: Offset(0, 4), blurRadius: 12, color: Color(0x66000000)),
    ],
    shadowLg: [
      BoxShadow(offset: Offset(0, 8), blurRadius: 32, color: Color(0x80000000)),
    ],
    shadowGlow: [BoxShadow(blurRadius: 16, color: AppColors.cyberGlow)],
    shadowGlowPrimary: [BoxShadow(blurRadius: 24, color: Color(0x26FFE6CB))],
    shadowLive: [BoxShadow(blurRadius: 8, color: Color(0x66E53935))],
    shadowFocus: [BoxShadow(spreadRadius: 3, color: AppColors.cyberPrimary)],
    shadowFocusTv: [
      BoxShadow(spreadRadius: 3, color: AppColors.cyberPrimary),
      BoxShadow(blurRadius: 16, color: AppColors.cyberGlow),
    ],
    overlayDark: Color(0xD9041C1C),
    overlayLight: Color(0x14FFFFFF),
    borderGrid: BorderSide(color: AppColors.cyberGridLine),
    borderOutline: BorderSide(color: AppColors.cyberOutline),
    borderPrimary: BorderSide(color: AppColors.cyberPrimary),
    gradientPlayer: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xA6000000),
        Color(0x00000000),
        Color(0x00000000),
        Color(0xE0000000),
      ],
      stops: [0.0, 0.3, 0.65, 1.0],
    ),
    gradientBackground: LinearGradient(
      begin: Alignment(-1, -1),
      end: Alignment(1, 1),
      colors: [Color(0xFF041C1C), Color(0xFF062828)],
    ),
    transitionFast: Duration(milliseconds: 120),
    transitionStd: Duration(milliseconds: 200),
    transitionSlow: Duration(milliseconds: 300),
  );

  static const classic = AiroEffects(
    shadowSm: [
      BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x1A000000)),
    ],
    shadowMd: [
      BoxShadow(offset: Offset(0, 4), blurRadius: 12, color: Color(0x26000000)),
    ],
    shadowLg: [
      BoxShadow(offset: Offset(0, 8), blurRadius: 32, color: Color(0x33000000)),
    ],
    shadowGlow: [],
    shadowGlowPrimary: [],
    shadowLive: [BoxShadow(blurRadius: 8, color: Color(0x66E53935))],
    shadowFocus: [BoxShadow(spreadRadius: 3, color: Color(0xFF6750A4))],
    shadowFocusTv: [BoxShadow(spreadRadius: 3, color: Color(0xFF6750A4))],
    overlayDark: Color(0xD9000000),
    overlayLight: Color(0x14000000),
    borderGrid: BorderSide(color: Color(0xFFCAC4D0)),
    borderOutline: BorderSide(color: Color(0xFF79747E)),
    borderPrimary: BorderSide(color: Color(0xFF6750A4)),
    gradientPlayer: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xA6000000),
        Color(0x00000000),
        Color(0x00000000),
        Color(0xE0000000),
      ],
      stops: [0.0, 0.3, 0.65, 1.0],
    ),
    gradientBackground: LinearGradient(
      colors: [Color(0xFFFFFBFE), Color(0xFFFFFBFE)],
    ),
    transitionFast: Duration(milliseconds: 120),
    transitionStd: Duration(milliseconds: 200),
    transitionSlow: Duration(milliseconds: 300),
  );

  static const bedtime = AiroEffects(
    shadowSm: [
      BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x4D000000)),
    ],
    shadowMd: [
      BoxShadow(offset: Offset(0, 4), blurRadius: 12, color: Color(0x66000000)),
    ],
    shadowLg: [
      BoxShadow(offset: Offset(0, 8), blurRadius: 32, color: Color(0x80000000)),
    ],
    shadowGlow: [],
    shadowGlowPrimary: [],
    shadowLive: [BoxShadow(blurRadius: 8, color: Color(0x66E53935))],
    shadowFocus: [BoxShadow(spreadRadius: 3, color: Color(0xFFFFE4B5))],
    shadowFocusTv: [BoxShadow(spreadRadius: 3, color: Color(0xFFFFE4B5))],
    overlayDark: Color(0xD9000000),
    overlayLight: Color(0x14FFFFFF),
    borderGrid: BorderSide(color: Color(0xFF2D2D2D)),
    borderOutline: BorderSide(color: Color(0xFF2D2D2D)),
    borderPrimary: BorderSide(color: Color(0xFFFFE4B5)),
    gradientPlayer: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xA6000000),
        Color(0x00000000),
        Color(0x00000000),
        Color(0xE0000000),
      ],
      stops: [0.0, 0.3, 0.65, 1.0],
    ),
    gradientBackground: LinearGradient(
      colors: [Color(0xFF000000), Color(0xFF000000)],
    ),
    transitionFast: Duration(milliseconds: 120),
    transitionStd: Duration(milliseconds: 200),
    transitionSlow: Duration(milliseconds: 300),
  );

  @override
  AiroEffects copyWith({
    List<BoxShadow>? shadowSm,
    List<BoxShadow>? shadowMd,
    List<BoxShadow>? shadowLg,
    List<BoxShadow>? shadowGlow,
    List<BoxShadow>? shadowGlowPrimary,
    List<BoxShadow>? shadowLive,
    List<BoxShadow>? shadowFocus,
    List<BoxShadow>? shadowFocusTv,
    Color? overlayDark,
    Color? overlayLight,
    BorderSide? borderGrid,
    BorderSide? borderOutline,
    BorderSide? borderPrimary,
    LinearGradient? gradientPlayer,
    LinearGradient? gradientBackground,
    Duration? transitionFast,
    Duration? transitionStd,
    Duration? transitionSlow,
  }) {
    return AiroEffects(
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowLg: shadowLg ?? this.shadowLg,
      shadowGlow: shadowGlow ?? this.shadowGlow,
      shadowGlowPrimary: shadowGlowPrimary ?? this.shadowGlowPrimary,
      shadowLive: shadowLive ?? this.shadowLive,
      shadowFocus: shadowFocus ?? this.shadowFocus,
      shadowFocusTv: shadowFocusTv ?? this.shadowFocusTv,
      overlayDark: overlayDark ?? this.overlayDark,
      overlayLight: overlayLight ?? this.overlayLight,
      borderGrid: borderGrid ?? this.borderGrid,
      borderOutline: borderOutline ?? this.borderOutline,
      borderPrimary: borderPrimary ?? this.borderPrimary,
      gradientPlayer: gradientPlayer ?? this.gradientPlayer,
      gradientBackground: gradientBackground ?? this.gradientBackground,
      transitionFast: transitionFast ?? this.transitionFast,
      transitionStd: transitionStd ?? this.transitionStd,
      transitionSlow: transitionSlow ?? this.transitionSlow,
    );
  }

  @override
  AiroEffects lerp(ThemeExtension<AiroEffects>? other, double t) {
    if (other is! AiroEffects) return this;
    return AiroEffects(
      shadowSm: t < 0.5 ? shadowSm : other.shadowSm,
      shadowMd: t < 0.5 ? shadowMd : other.shadowMd,
      shadowLg: t < 0.5 ? shadowLg : other.shadowLg,
      shadowGlow: t < 0.5 ? shadowGlow : other.shadowGlow,
      shadowGlowPrimary:
          t < 0.5 ? shadowGlowPrimary : other.shadowGlowPrimary,
      shadowLive: t < 0.5 ? shadowLive : other.shadowLive,
      shadowFocus: t < 0.5 ? shadowFocus : other.shadowFocus,
      shadowFocusTv: t < 0.5 ? shadowFocusTv : other.shadowFocusTv,
      overlayDark: Color.lerp(overlayDark, other.overlayDark, t)!,
      overlayLight: Color.lerp(overlayLight, other.overlayLight, t)!,
      borderGrid: BorderSide.lerp(borderGrid, other.borderGrid, t),
      borderOutline: BorderSide.lerp(borderOutline, other.borderOutline, t),
      borderPrimary: BorderSide.lerp(borderPrimary, other.borderPrimary, t),
      gradientPlayer:
          LinearGradient.lerp(gradientPlayer, other.gradientPlayer, t)!,
      gradientBackground:
          LinearGradient.lerp(gradientBackground, other.gradientBackground, t)!,
      transitionFast: t < 0.5 ? transitionFast : other.transitionFast,
      transitionStd: t < 0.5 ? transitionStd : other.transitionStd,
      transitionSlow: t < 0.5 ? transitionSlow : other.transitionSlow,
    );
  }
}
