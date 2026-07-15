import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AiroTextField extends StatelessWidget {
  const AiroTextField({
    super.key,
    this.controller,
    this.label,
    this.placeholder,
    this.errorText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.obscureText = false,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.textInputAction,
    this.keyboardType,
  });

  final TextEditingController? controller;
  final String? label;
  final String? placeholder;
  final String? errorText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool obscureText;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label!.toUpperCase(),
              style: const TextStyle(
                color: AppColors.cyberMutedText,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
              ),
            ),
          ),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscureText,
          maxLines: maxLines,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          keyboardType: keyboardType,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.cyberText,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            errorText: hasError ? errorText : null,
            errorStyle: const TextStyle(
              color: AppColors.cyberError,
              fontSize: 11,
            ),
          ),
        ),
        if (hintText != null && !hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              hintText!,
              style: const TextStyle(
                color: AppColors.cyberMutedText,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}
