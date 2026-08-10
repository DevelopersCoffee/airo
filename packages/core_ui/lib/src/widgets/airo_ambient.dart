import 'package:flutter/material.dart';

import '../theme/airo_domain.dart';
import '../theme/airo_visual_tokens.dart';
import '../theme/airo_spacing.dart';

enum AiroSurfaceLevel { base, raised, floating }

/// The inexpensive Ambient Precision canvas.
///
/// This uses a static gradient rather than a backdrop filter so it remains
/// suitable for list-heavy, web, and TV surfaces.
class AiroAmbientBackground extends StatelessWidget {
  const AiroAmbientBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visual = AiroVisualTokens.of(context);
    final domain = AiroDomainTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            visual.canvas,
            Color.alphaBlend(
              domain.accent.withValues(alpha: 0.045),
              visual.canvas,
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Shared premium content surface with consistent depth, border, and geometry.
class AiroSurface extends StatelessWidget {
  const AiroSurface({
    required this.child,
    super.key,
    this.level = AiroSurfaceLevel.base,
    this.padding = AiroSpacing.paddingMd,
    this.onTap,
    this.semanticLabel,
    this.accented = false,
  });

  final Widget child;
  final AiroSurfaceLevel level;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool accented;

  @override
  Widget build(BuildContext context) {
    final visual = AiroVisualTokens.of(context);
    final domain = AiroDomainTokens.of(context);
    final color = switch (level) {
      AiroSurfaceLevel.base => visual.surface,
      AiroSurfaceLevel.raised => visual.surfaceRaised,
      AiroSurfaceLevel.floating => visual.surfaceFloating,
    };
    final borderColor = accented
        ? domain.accent.withValues(alpha: 0.5)
        : visual.border;

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          borderRadius: visual.mediumRadius,
          child: content,
        ),
      );
    }

    return Material(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: visual.mediumRadius,
        side: BorderSide(color: borderColor),
      ),
      child: content,
    );
  }
}

/// Responsive, semantic page heading for top-level product surfaces.
class AiroPageHeader extends StatelessWidget {
  const AiroPageHeader({
    required this.title,
    super.key,
    this.eyebrow,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final domain = AiroDomainTokens.of(context);

    final heading = Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow case final eyebrow?)
            Text(
              eyebrow.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: domain.accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          if (eyebrow != null) const SizedBox(height: AiroSpacing.sm),
          Text(title, style: theme.textTheme.headlineLarge),
          if (subtitle case final subtitle?) ...[
            const SizedBox(height: AiroSpacing.sm),
            Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );

    if (actions.isEmpty) return heading;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: AiroSpacing.md),
              Wrap(
                spacing: AiroSpacing.sm,
                runSpacing: AiroSpacing.sm,
                children: actions,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: AiroSpacing.lg),
            Wrap(
              spacing: AiroSpacing.sm,
              runSpacing: AiroSpacing.sm,
              children: actions,
            ),
          ],
        );
      },
    );
  }
}
