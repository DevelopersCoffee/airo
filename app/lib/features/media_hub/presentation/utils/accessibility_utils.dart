import 'package:flutter/material.dart';

/// Accessibility utilities for Media Hub components.
///
/// Ensures WCAG AA compliance with:
/// - Touch targets ≥ 44px
/// - Color contrast ≥ 4.5:1
/// - Semantic labels on all controls
/// - Dynamic text support
/// - Clear focus states (web)
class MediaHubAccessibility {
  MediaHubAccessibility._();

  /// Minimum touch target size per WCAG AA guidelines (44px)
  static const double minTouchTarget = 44.0;

  /// Recommended touch target size for better accessibility (48px)
  static const double recommendedTouchTarget = 48.0;

  /// Minimum contrast ratio for normal text per WCAG AA (4.5:1)
  static const double minContrastRatio = 4.5;

  /// Minimum contrast ratio for large text per WCAG AA (3:1)
  static const double minLargeTextContrastRatio = 3.0;

  /// Focus indicator width
  static const double focusIndicatorWidth = 2.0;

  /// Focus indicator offset
  static const double focusIndicatorOffset = 2.0;

  /// Calculates the contrast ratio between two colors.
  ///
  /// Returns a value between 1:1 (same color) and 21:1 (black on white).
  /// WCAG AA requires ≥ 4.5:1 for normal text and ≥ 3:1 for large text.
  static double getContrastRatio(Color foreground, Color background) {
    final fgLuminance = foreground.computeLuminance();
    final bgLuminance = background.computeLuminance();

    final lighter = fgLuminance > bgLuminance ? fgLuminance : bgLuminance;
    final darker = fgLuminance > bgLuminance ? bgLuminance : fgLuminance;

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Checks if the contrast ratio meets WCAG AA requirements for normal text.
  static bool meetsContrastRequirements(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= minContrastRatio;
  }

  /// Checks if the contrast ratio meets WCAG AA requirements for large text.
  static bool meetsLargeTextContrastRequirements(
    Color foreground,
    Color background,
  ) {
    return getContrastRatio(foreground, background) >=
        minLargeTextContrastRatio;
  }

  /// Returns a focus decoration for web focus states.
  static BoxDecoration getFocusDecoration(Color focusColor) {
    return BoxDecoration(
      border: Border.all(color: focusColor, width: focusIndicatorWidth),
      borderRadius: BorderRadius.circular(4),
    );
  }

  /// Wraps a widget with an accessible touch target.
  ///
  /// Ensures the widget meets the minimum touch target size.
  static Widget ensureMinTouchTarget({
    required Widget child,
    double minSize = minTouchTarget,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      child: Center(child: child),
    );
  }
}

/// A button wrapper that ensures accessibility compliance.
///
/// Features:
/// - Minimum touch target size (44px)
/// - Semantic label for screen readers
/// - Focus state for keyboard navigation
/// - Tooltip on hover
class AccessibleButton extends StatefulWidget {
  const AccessibleButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.tooltip,
    this.enabled = true,
    this.minTouchTarget = MediaHubAccessibility.minTouchTarget,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String semanticLabel;
  final String? tooltip;
  final bool enabled;
  final double minTouchTarget;

  @override
  State<AccessibleButton> createState() => _AccessibleButtonState();
}

class _AccessibleButtonState extends State<AccessibleButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    Widget button = Semantics(
      label: widget.semanticLabel,
      button: true,
      enabled: widget.enabled,
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: Container(
            constraints: BoxConstraints(
              minWidth: widget.minTouchTarget,
              minHeight: widget.minTouchTarget,
            ),
            decoration: _isFocused
                ? MediaHubAccessibility.getFocusDecoration(
                    Theme.of(context).colorScheme.primary,
                  )
                : null,
            child: Center(child: widget.child),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}
