import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'responsive_center.dart';

/// Adaptive text field that optimizes layout for different screen sizes
class AdaptiveTextField extends StatelessWidget {
  const AdaptiveTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.enabled,
    this.readOnly = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool autofocus;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: decoration?.copyWith(
        // Add hover effects on desktop
        border: isDesktop ? const OutlineInputBorder() : decoration?.border,
      ),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: style,
      textAlign: textAlign,
      autofocus: autofocus,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      enabled: enabled,
      readOnly: readOnly,
    );
  }
}

/// Adaptive form field that wraps TextField with responsive styling
class AdaptiveFormField extends StatelessWidget {
  const AdaptiveFormField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.hintText,
    this.helperText,
    this.onChanged,
  });

  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? hintText;
  final String? helperText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

