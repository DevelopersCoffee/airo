import 'package:flutter/material.dart';

enum AiroButtonType {
  primary,
  secondary,
  outlined,
  text,
}

enum AiroButtonSize {
  small,
  medium,
  large,
}

class AiroButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AiroButtonType type;
  final AiroButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final Color? color;
  final double? width;

  const AiroButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AiroButtonType.primary,
    this.size = AiroButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine button style based on type
    ButtonStyle buttonStyle;
    Color textColor;

    switch (type) {
      case AiroButtonType.primary:
        buttonStyle = ElevatedButton.styleFrom(
          backgroundColor: color ?? colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
        );
        textColor = colorScheme.onPrimary;
        break;
      case AiroButtonType.secondary:
        buttonStyle = ElevatedButton.styleFrom(
          backgroundColor: color ?? colorScheme.secondary,
          foregroundColor: colorScheme.onSecondary,
          elevation: 1,
        );
        textColor = colorScheme.onSecondary;
        break;
      case AiroButtonType.outlined:
        buttonStyle = OutlinedButton.styleFrom(
          foregroundColor: color ?? colorScheme.primary,
          side: BorderSide(color: color ?? colorScheme.primary),
        );
        textColor = color ?? colorScheme.primary;
        break;
      case AiroButtonType.text:
        buttonStyle = TextButton.styleFrom(
          foregroundColor: color ?? colorScheme.primary,
        );
        textColor = color ?? colorScheme.primary;
        break;
    }

    // Determine padding based on size
    EdgeInsets padding;
    double fontSize;
    double iconSize;

    switch (size) {
      case AiroButtonSize.small:
        padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
        fontSize = 12;
        iconSize = 16;
        break;
      case AiroButtonSize.medium:
        padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
        fontSize = 14;
        iconSize = 18;
        break;
      case AiroButtonSize.large:
        padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
        fontSize = 16;
        iconSize = 20;
        break;
    }

    buttonStyle = buttonStyle.copyWith(
      padding: WidgetStateProperty.all(padding),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );

    Widget child;
    if (isLoading) {
      child = SizedBox(
        height: iconSize,
        width: iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
          ),
        ],
      );
    } else {
      child = Text(
        text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
      );
    }

    Widget button;
    switch (type) {
      case AiroButtonType.primary:
      case AiroButtonType.secondary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: child,
        );
        break;
      case AiroButtonType.outlined:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: child,
        );
        break;
      case AiroButtonType.text:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: child,
        );
        break;
    }

    if (width != null) {
      return SizedBox(
        width: width,
        child: button,
      );
    }

    return button;
  }
}
