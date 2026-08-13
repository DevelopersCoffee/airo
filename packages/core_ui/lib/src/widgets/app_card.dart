import 'package:flutter/material.dart';

import '../theme/airo_spacing.dart';

/// Standard card widget with consistent styling
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.onTap,
    this.elevation,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? elevation;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding ?? AiroSpacing.cardPadding,
      child: child,
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: AiroSpacing.borderRadiusMd,
        child: content,
      );
    }

    return Card(margin: margin, elevation: elevation, child: content);
  }
}
