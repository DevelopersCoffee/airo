import 'package:flutter/material.dart';
import 'responsive_center.dart';

/// Adaptive dialog that shows as full-screen on mobile and centered dialog on desktop
class AdaptiveDialog {
  /// Show an adaptive dialog that adjusts based on screen size
  ///
  /// On mobile (<600px): Full-screen bottom sheet
  /// On tablet/desktop (>=600px): Centered dialog with max width
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    String? barrierLabel,
    double maxWidth = 600,
    double maxHeight = 800,
  }) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    if (isMobile) {
      // Mobile: Full-screen bottom sheet
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        isDismissible: barrierDismissible,
        useSafeArea: true,
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: builder(context),
        ),
      );
    } else {
      // Desktop: Centered dialog
      return showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        barrierLabel: barrierLabel,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: builder(context),
          ),
        ),
      );
    }
  }

  /// Show an adaptive alert dialog
  static Future<T?> showAlert<T>({
    required BuildContext context,
    Widget? title,
    Widget? content,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) {
    return show<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      maxWidth: 400,
      maxHeight: 600,
      builder: (context) =>
          AlertDialog(title: title, content: content, actions: actions),
    );
  }
}

/// Adaptive bottom sheet that shows as draggable sheet on mobile
/// and fixed-size dialog on desktop
class AdaptiveBottomSheet {
  /// Show an adaptive bottom sheet
  ///
  /// On mobile: Draggable bottom sheet
  /// On desktop: Centered dialog
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    double initialChildSize = 0.6,
    double minChildSize = 0.4,
    double maxChildSize = 0.9,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    if (isMobile) {
      // Mobile: Draggable bottom sheet
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: builder(context),
          ),
        ),
      );
    } else {
      // Desktop: Centered dialog
      return showDialog<T>(
        context: context,
        barrierDismissible: isDismissible,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            child: builder(context),
          ),
        ),
      );
    }
  }
}
